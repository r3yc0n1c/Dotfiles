## Setup Claude Code (Free with Gemini models)

### 1. Install Claude Code and verrify
```powershell 
npm install -g @anthropic-ai/claude-code

# verify
claude --version
```

### 2. Get Gemini API KEY

- Go to https://aistudio.google.com/ and click on "Get API Key" in the bottom left corner
- Save it somewhere

### 3. Cook the Proxy

- Install LiteLLM
```powershell 
pip install 'litellm[proxy]'
```

- Create `litellm_config.yaml` in your home folder
```powershell
touch C:\Users\<YOUR-USERNAME>\litellm_config.yaml
```
- Put these configs and save the file
```
model_list:
  - model_name: gemini-2.5-flash
    litellm_params:
      model: gemini/gemini-2.5-flash
      api_key: YOUR-GEMINI-KEY

litellm_settings:
  drop_params: true
```

- Start the proxy
```powershell
cd ~
litellm --config litellm_config.yaml --port 4000
```

- Claude Code flow `Claude Code -> Anthropic format -> LiteLLM -> OpenAI format -> Gemini`


### 4. Setup ENV variables

Windows
```powershell
setx ANTHROPIC_API_KEY "AIza-YOUR-GEMINI-KEY-HERE"
setx ANTHROPIC_AUTH_TOKEN "AIza-YOUR-GEMINI-KEY-HERE"
setx ANTHROPIC_BASE_URL "http://localhost:4000"
setx ANTHROPIC_MODEL "gemini-2.5-flash"
```

Linux/MacOS
```sh
ANTHROPIC_API_KEY=YOUR-GEMINI-KEY-HERE
ANTHROPIC_AUTH_TOKEN=YOUR-GEMINI-KEY-HERE
ANTHROPIC_BASE_URL=http://localhost:4000
ANTHROPIC_MODEL=gemini-2.5-flash
```

### 5. Refresh `env` and start Claude Code
```powershell
cd your_project
claude .

# When it asks for "Do you want to use this API key?"
# Select "No" and enter
```
