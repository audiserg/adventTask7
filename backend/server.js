import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Система ограничений по IP
const DAILY_LIMIT = parseInt(process.env.DAILY_MESSAGE_LIMIT || '10', 10);
const ipRequestCounts = new Map(); // { ip: { date: 'YYYY-MM-DD', count: number } }

// Функция для получения IP адреса
function getClientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0] || 
         req.headers['x-real-ip'] || 
         req.connection?.remoteAddress || 
         req.socket?.remoteAddress ||
         'unknown';
}

// Функция для получения текущей даты в формате YYYY-MM-DD
function getCurrentDate() {
  return new Date().toISOString().split('T')[0];
}

// Функция для проверки лимита (без увеличения счетчика)
function checkLimit(ip) {
  const today = getCurrentDate();
  const ipData = ipRequestCounts.get(ip);

  if (!ipData || ipData.date !== today) {
    // Новый день или новый IP
    return { allowed: true, count: 0, remaining: DAILY_LIMIT };
  }

  if (ipData.count >= DAILY_LIMIT) {
    return { allowed: false, count: ipData.count, remaining: 0 };
  }

  return { allowed: true, count: ipData.count, remaining: DAILY_LIMIT - ipData.count };
}

// Функция для увеличения счетчика запросов
function incrementLimit(ip) {
  const today = getCurrentDate();
  const ipData = ipRequestCounts.get(ip);

  if (!ipData || ipData.date !== today) {
    // Новый день или новый IP - создаем новую запись
    ipRequestCounts.set(ip, { date: today, count: 1 });
    return { count: 1, remaining: DAILY_LIMIT - 1 };
  }

  // Увеличиваем счетчик
  ipData.count++;
  ipRequestCounts.set(ip, ipData);
  return { count: ipData.count, remaining: DAILY_LIMIT - ipData.count };
}

// Очистка старых записей (запускается каждый час)
setInterval(() => {
  const today = getCurrentDate();
  for (const [ip, data] of ipRequestCounts.entries()) {
    if (data.date !== today) {
      ipRequestCounts.delete(ip);
    }
  }
}, 60 * 60 * 1000); // Каждый час

// Middleware
app.use(cors({
  origin: '*', // В production укажите конкретный домен
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

// Middleware для логирования запросов
app.use((req, res, next) => {
  const start = Date.now();
  const timestamp = new Date().toISOString();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${timestamp}] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${duration}ms)`);
  });
  
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Endpoint для получения списка доступных моделей
app.get('/api/models', async (req, res) => {
  try {
    console.log('📋 Request for available models');
    
    // Попытка получить список моделей из Hugging Face API
    const hfApiKey = process.env.HUGGINGFACE_API_KEY;
    let hfModels = [];
    
    if (hfApiKey) {
      try {
        // Попытка получить список через Hub API
        const hubResponse = await fetch('https://huggingface.co/api/models?filter=text-generation-inference&sort=downloads&direction=-1&limit=50', {
          headers: {
            'Authorization': `Bearer ${hfApiKey}`,
          },
        });
        
        if (hubResponse.ok) {
          const hubData = await hubResponse.json();
          // Фильтруем только chat модели (исключаем gpt2, base модели и т.д.)
          // Используем строгую фильтрацию для проверенных моделей
          hfModels = hubData
            .filter(model => {
              if (!model.id || !model.id.includes('/')) return false;
              const modelId = model.id.toLowerCase();
              
              // Исключаем модели, которые точно не chat
              const excludePatterns = [
                'gpt2',
                'gpt-2',
                'base',
                'vision',
                'embedding',
                'tokenizer',
                'openai-community/gpt2',
                'qwen3-', // Qwen3 модели без -Instruct не поддерживают chat
                'qwen2-0', // Qwen2.0 без -Instruct
                '-0.6b',
                '-1.5b',
                '-3b-instruct', // Могут быть недоступны
              ];
              
              // Строгие паттерны для включения - только проверенные форматы
              const includePatterns = [
                'qwen2.5-', // Qwen 2.5 с -Instruct
                'llama-3.1-', // Llama 3.1
                'llama-3.2-', // Llama 3.2
                'llama-2-7b-chat', // Llama 2 chat
                'mistral-7b-instruct',
                'mixtral-8x7b-instruct',
                'gemma-2-', // Gemma 2
                'deepseek-', // DeepSeek модели
                'glm-', // GLM модели
              ];
              
              const hasExclude = excludePatterns.some(pattern => modelId.includes(pattern));
              
              // Для Qwen - только с -Instruct в конце
              if (modelId.includes('qwen') && !modelId.includes('-instruct')) {
                return false;
              }
              
              // Для Llama - только с -Instruct или -chat
              if (modelId.includes('llama') && !modelId.includes('-instruct') && !modelId.includes('-chat')) {
                return false;
              }
              
              // Для Mistral - только с -Instruct
              if (modelId.includes('mistral') && !modelId.includes('-instruct')) {
                return false;
              }
              
              // Для Gemma - только с -it (instruction tuned)
              if (modelId.includes('gemma') && !modelId.includes('-it')) {
                return false;
              }
              
              const hasInclude = includePatterns.some(pattern => modelId.includes(pattern));
              
              return !hasExclude && hasInclude;
            })
            .map(model => model.id)
            .slice(0, 30); // Ограничиваем до 30 проверенных моделей
        }
      } catch (error) {
        console.warn('⚠️ Could not fetch models from Hub API:', error.message);
      }
    }
    
    // Если не удалось получить динамически или список пустой, используем предустановленный список
    // Используем только модели, которые точно поддерживают chat completion через router API
    // Эти модели проверены и работают через router.huggingface.co/v1/chat/completions
    if (hfModels.length === 0) {
      console.log('📋 Using predefined model list (no models from Hub API)');
      hfModels = [
        // Qwen 2.5 модели (проверенные)
        'Qwen/Qwen2.5-72B-Instruct',
        'Qwen/Qwen2.5-32B-Instruct',
        'Qwen/Qwen2.5-14B-Instruct',
        'Qwen/Qwen2.5-7B-Instruct',
        'Qwen/Qwen2.5-3B-Instruct',
        // Llama модели (проверенные)
        'meta-llama/Llama-3.1-8B-Instruct',
        'meta-llama/Llama-3.1-70B-Instruct',
        'meta-llama/Llama-3.2-3B-Instruct',
        'meta-llama/Llama-2-7b-chat-hf',
        // Gemma модели (проверенные)
        'google/gemma-2-2b-it',
        'google/gemma-2-9b-it',
        // Mistral модели (проверенные)
        'mistralai/Mistral-7B-Instruct-v0.2',
        'mistralai/Mixtral-8x7B-Instruct-v0.1',
        // DeepSeek модели (проверенные)
        'deepseek-ai/DeepSeek-V3-0324',
        'deepseek-ai/DeepSeek-V2-Lite',
        'deepseek-ai/DeepSeek-R1',
        // GLM модели (проверенные)
        'zai-org/GLM-4.7-Flash:novita',
      ];
    } else {
      // Дополнительно фильтруем динамически полученные модели
      // Удаляем модели, которые точно не работают
      hfModels = hfModels.filter(model => {
        const modelId = model.toLowerCase();
        // Исключаем проблемные модели
        const problematicPatterns = [
          'qwen3-',
          'qwen2-0',
          '-0.6b',
          '-1.5b',
          'qwen2.5-1.5b',
        ];
        return !problematicPatterns.some(pattern => modelId.includes(pattern));
      });
      
      // Добавляем проверенные модели в начало списка
      const verifiedModels = [
        'Qwen/Qwen2.5-7B-Instruct',
        'Qwen/Qwen2.5-14B-Instruct',
        'meta-llama/Llama-3.1-8B-Instruct',
        'google/gemma-2-2b-it',
        'mistralai/Mistral-7B-Instruct-v0.2',
        'zai-org/GLM-4.7-Flash:novita',
      ];
      
      // Объединяем проверенные модели с динамическими, убирая дубликаты
      const allModels = [...new Set([...verifiedModels, ...hfModels])];
      hfModels = allModels.slice(0, 30);
    }
    
    // Список моделей DeepSeek
    const deepseekModels = [
      'deepseek-ai/DeepSeek-V3-0324',
      'deepseek-chat',
      'deepseek-reasoner',
      'deepseek-chat-reasoner',
      'deepseek-ai/DeepSeek-V2-Lite',
      'deepseek-ai/DeepSeek-R1',
    ];
    
    const response = {
      providers: {
        deepseek: {
          name: 'DeepSeek',
          models: deepseekModels,
          presets: PRESET_MODELS.deepseek,
        },
        huggingface: {
          name: 'Hugging Face',
          models: hfModels,
          presets: PRESET_MODELS.huggingface,
        },
      },
      defaultProvider: process.env.DEFAULT_PROVIDER || 'deepseek',
    };
    
    console.log(`✅ Returning ${deepseekModels.length} DeepSeek models and ${hfModels.length} Hugging Face models`);
    res.json(response);
  } catch (error) {
    console.error('❌ Error fetching models:', error.message);
    res.status(500).json({ 
      error: 'Failed to fetch models',
      message: error.message 
    });
  }
});

// Предустановленные модели для быстрого доступа
const PRESET_MODELS = {
  deepseek: {
    top: 'deepseek-ai/DeepSeek-V3-0324',
    medium: 'deepseek-chat',
    light: 'deepseek-chat',
  },
  huggingface: {
    top: 'Qwen/Qwen2.5-72B-Instruct',
    medium: 'Qwen/Qwen2.5-7B-Instruct',
    light: 'google/gemma-2-2b-it',
  },
};

// Функция для отправки запроса к DeepSeek API
async function sendToDeepSeek(messagesWithSystem, temperature, model) {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    throw new Error('DEEPSEEK_API_KEY is not set in environment variables');
  }

  const deepseekUrl = 'https://api.deepseek.com/v1/chat/completions';
  const requestBody = {
    model: model || process.env.DEEPSEEK_MODEL || 'deepseek-chat',
    messages: messagesWithSystem,
    stream: false,
  };
  
  if (temperature !== undefined && temperature !== null) {
    requestBody.temperature = temperature;
  }
  
  console.log('🚀 Sending request to DeepSeek API:');
  console.log('URL:', deepseekUrl);
  console.log('Model:', requestBody.model);
  console.log('Messages count:', messagesWithSystem.length);
  
  const response = await fetch(deepseekUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('❌ DeepSeek API error:', response.status, errorText);
    throw new Error(`DeepSeek API error: ${response.status} - ${errorText}`);
  }

  return await response.json();
}

// Функция для отправки запроса к Hugging Face API
async function sendToHuggingFace(messagesWithSystem, temperature, model) {
  const apiKey = process.env.HUGGINGFACE_API_KEY;
  if (!apiKey) {
    throw new Error('HUGGINGFACE_API_KEY is not set in environment variables');
  }

  const hfUrl = 'https://router.huggingface.co/v1/chat/completions';
  const requestBody = {
    model: model || process.env.HUGGINGFACE_MODEL || 'Qwen/Qwen2.5-7B-Instruct',
    messages: messagesWithSystem,
    stream: false,
  };
  
  if (temperature !== undefined && temperature !== null) {
    requestBody.temperature = temperature;
  }
  
  console.log('🚀 Sending request to Hugging Face API:');
  console.log('URL:', hfUrl);
  console.log('Model:', requestBody.model);
  console.log('Messages count:', messagesWithSystem.length);
  
  const response = await fetch(hfUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('❌ Hugging Face API error:', response.status, errorText);
    console.error('❌ Model used:', requestBody.model);
    
    // Более детальная обработка ошибок
    let errorMessage = `Hugging Face API error: ${response.status}`;
    try {
      const errorData = JSON.parse(errorText);
      // errorData.error может быть объектом с полем message
      if (errorData.error) {
        if (typeof errorData.error === 'string') {
          errorMessage += ` - ${errorData.error}`;
        } else if (errorData.error.message) {
          errorMessage += ` - ${errorData.error.message}`;
        } else if (errorData.error.type) {
          errorMessage += ` - ${errorData.error.type}: ${errorData.error.message || errorData.error.code || ''}`;
        } else {
          errorMessage += ` - ${JSON.stringify(errorData.error)}`;
        }
      } else if (errorData.message) {
        errorMessage += ` - ${errorData.message}`;
      } else {
        errorMessage += ` - ${errorText}`;
      }
    } catch (e) {
      errorMessage += ` - ${errorText}`;
    }
    
    // Если модель не поддерживается или не найдена, предлагаем альтернативу
    if (response.status === 404 || 
        response.status === 400 && (
          errorText.includes('not found') || 
          errorText.includes('Model') || 
          errorText.includes('not a chat model') ||
          errorText.includes('model_not_supported')
        )) {
      errorMessage += `. Модель "${requestBody.model}" не поддерживает chat completion или недоступна. Попробуйте другую модель из списка.`;
    }
    
    throw new Error(errorMessage);
  }

  return await response.json();
}

// Chat endpoint - proxies to DeepSeek or Hugging Face API
app.post('/api/chat', async (req, res) => {
  try {
    console.log('📨 Received chat request');
    const { messages, temperature, systemPrompt, provider, model } = req.body;
    console.log(`📝 Messages count: ${messages?.length || 0}`);
    console.log(`🌡️ Temperature: ${temperature ?? 'default'}`);
    console.log(`📋 System prompt: ${systemPrompt ? 'custom' : 'default'}`);
    console.log(`🔌 Provider: ${provider || 'default (deepseek)'}`);
    console.log(`🤖 Model: ${model || 'default'}`);
    
    // Логируем содержимое сообщений
    if (messages && Array.isArray(messages)) {
      console.log('💬 Messages content:');
      messages.forEach((msg, index) => {
        console.log(`  [${index + 1}] ${msg.role}: ${msg.content?.substring(0, 200)}${msg.content?.length > 200 ? '...' : ''}`);
      });
    }

    if (!messages || !Array.isArray(messages)) {
      return res.status(400).json({ 
        error: 'Invalid request. Messages array is required.' 
      });
    }

    // Определяем провайдера
    const selectedProvider = provider || process.env.DEFAULT_PROVIDER || 'deepseek';
    
    // Определяем модель
    let selectedModel = model;
    if (!selectedModel && selectedProvider === 'deepseek') {
      selectedModel = process.env.DEEPSEEK_MODEL || 'deepseek-chat';
    } else if (!selectedModel && selectedProvider === 'huggingface') {
      selectedModel = process.env.HUGGINGFACE_MODEL || 'Qwen/Qwen2.5-7B-Instruct';
    }

    // Используем переданный системный промпт, если он есть
    let messagesWithSystem = messages;
    
    if (systemPrompt && systemPrompt.trim().length > 0) {
      // Добавляем системный промпт в начало массива сообщений только если он передан
      messagesWithSystem = [
        {
          role: 'system',
          content: systemPrompt
        },
        ...messages
      ];
    }

    // Отправляем запрос в зависимости от провайдера
    let data;
    if (selectedProvider === 'huggingface') {
      console.log('🤖 Sending request to Hugging Face API...');
      data = await sendToHuggingFace(messagesWithSystem, temperature, selectedModel);
    } else {
      console.log('🤖 Sending request to DeepSeek API...');
      data = await sendToDeepSeek(messagesWithSystem, temperature, selectedModel);
    }

    const aiResponse = data.choices?.[0]?.message?.content || 'No response';
    console.log(`✅ Received response from ${selectedProvider} (${aiResponse.length} chars)`);
    console.log(`📄 Full response:`);
    console.log(aiResponse);
    console.log('─'.repeat(80));
    
    res.json(data);
  } catch (error) {
    console.error('❌ Error processing chat request:', error.message);
    console.error('Stack:', error.stack);
    
    // Определяем статус код ошибки
    let statusCode = 500;
    let errorMessage = error.message;
    
    if (error.message.includes('API error:')) {
      statusCode = 502; // Bad Gateway
    } else if (error.message.includes('is not set')) {
      statusCode = 500;
      errorMessage = 'Server configuration error: API key not set';
    }
    
    res.status(statusCode).json({ 
      error: 'Internal server error',
      message: errorMessage 
    });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
