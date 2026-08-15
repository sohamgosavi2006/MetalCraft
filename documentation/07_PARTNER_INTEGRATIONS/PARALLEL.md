# Parallel Integration Architecture

## Role

Parallel is the **secondary partner** integration. It provides external creative research capabilities that the Gemini agent can invoke when creative context is needed.

## When Parallel Is Called

The agent decides WHEN research is needed. It is NOT called for every request.

**Call Parallel when**:
- User references specific filmmaking styles ("make it look like Blade Runner")
- User requests trend-aware editing ("current Instagram aesthetic")
- User needs creative references ("golden hour cinematography techniques")
- Agent is uncertain about creative direction

**Do NOT call Parallel when**:
- Simple technical operations ("increase brightness")
- User provides explicit parameters ("blur with sigma 5")
- Repeat requests with same context

## MCP Tool: research_creative_context

```python
@tool
def research_creative_context(
    query: str,
    topic: str = "cinematography",
    max_results: int = 5
) -> dict:
    """Research creative context using Parallel MCP.
    
    Args:
        query: Natural language research query
        topic: Research domain (cinematography, photography, color theory, editing)
        max_results: Maximum number of results
    
    Returns:
        dict with:
            - results: list of research findings with citations
            - summary: brief synthesis of findings
            - grounding: source references
    """
```

## Input/Output

**Input**:
```json
{
  "query": "golden hour cinematography color grading techniques",
  "topic": "cinematography",
  "max_results": 5
}
```

**Output**:
```json
{
  "results": [
    {
      "title": "Golden Hour Color Grading",
      "content": "Golden hour produces warm tones with color temperatures around 3500-4500K...",
      "source": "cinematography.reference.com",
      "relevance": 0.92
    }
  ],
  "summary": "Golden hour grading emphasizes warm tones (temperature +0.3-0.5), increased saturation, slight exposure boost...",
  "grounding": ["source1", "source2"]
}
```

## Security

- Parallel API key in Secret Manager
- User input sanitized before passing to Parallel (prompt injection protection)
- Results are information only — Gemini interprets them
- Timeout: 10 seconds, fallback to no-research mode
- No user media sent to Parallel (text queries only)
