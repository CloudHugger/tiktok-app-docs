import Foundation

struct EndpointPreset: Identifiable, Sendable {
    let id: UUID
    let name: String
    let baseURL: String
    let notes: String

    init(name: String, baseURL: String, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.baseURL = baseURL
        self.notes = notes
    }
}

enum EndpointLibrary {
    static let local: [EndpointPreset] = [
        EndpointPreset(name: "Ollama",                  baseURL: "http://localhost:11434",    notes: "Default Ollama port"),
        EndpointPreset(name: "LM Studio",               baseURL: "http://localhost:1234/v1",  notes: "OpenAI-compatible"),
        EndpointPreset(name: "Jan",                     baseURL: "http://localhost:1337/v1",  notes: "OpenAI-compatible"),
        EndpointPreset(name: "Open WebUI",              baseURL: "http://localhost:3000/openai/v1", notes: "Requires Open WebUI running"),
        EndpointPreset(name: "AnythingLLM",             baseURL: "http://localhost:3001/api/openai", notes: "OpenAI-compatible"),
        EndpointPreset(name: "llamafile",               baseURL: "http://localhost:8080/v1",  notes: "OpenAI-compatible"),
        EndpointPreset(name: "LocalAI",                 baseURL: "http://localhost:8080/v1",  notes: "OpenAI-compatible"),
        EndpointPreset(name: "text-generation-webui",   baseURL: "http://localhost:5000/v1",  notes: "OpenAI extension required"),
    ]

    static let cloud: [EndpointPreset] = [
        EndpointPreset(name: "Groq Cloud",   baseURL: "https://api.groq.com/openai/v1",          notes: "Very fast inference"),
        EndpointPreset(name: "Together AI",  baseURL: "https://api.together.xyz/v1",              notes: "Many open models"),
        EndpointPreset(name: "Fireworks AI", baseURL: "https://api.fireworks.ai/inference/v1",    notes: "Fast open model inference"),
        EndpointPreset(name: "OpenRouter",   baseURL: "https://openrouter.ai/api/v1",             notes: "Routes to 100+ models"),
        EndpointPreset(name: "Perplexity API", baseURL: "https://api.perplexity.ai",              notes: "Sonar models"),
        EndpointPreset(name: "Mistral API",  baseURL: "https://api.mistral.ai/v1",                notes: "Mistral models"),
        EndpointPreset(name: "Cohere",       baseURL: "https://api.cohere.com/compatibility/v1",  notes: "Command R+ models"),
        EndpointPreset(name: "OpenAI",       baseURL: "https://api.openai.com/v1",                notes: "GPT-4o, o1, etc."),
        EndpointPreset(name: "Anthropic (direct)", baseURL: "https://api.anthropic.com/v1",       notes: "Direct Anthropic API"),
    ]

    static var all: [EndpointPreset] { local + cloud }
}
