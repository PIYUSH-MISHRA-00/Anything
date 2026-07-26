# Web Content Trust Model

## Principle

Every web resource is potentially hostile. Retrieved content is DATA, not instructions.

## Threats

- Prompt injection in retrieved content
- Malicious instructions in web pages
- Unsafe code in retrieved sources
- License traps
- Tracking URLs

## Defenses

- Content treated as untrusted evidence
- Never obey instructions in retrieved pages
- Isolate retrieved content from system prompts
- Validate all URLs before retrieval
- Block localhost/private IPs by default
- No code execution from retrieved sources

## URL Safety

Rejected:
- file:// URLs
- javascript: URLs
- data: URLs (where unsafe)
- localhost/loopback
- Private RFC1918 ranges
- Link-local addresses
- Malformed URLs

## Source Code Policy

Downloaded source is NEVER:
- Executed
- Compiled
- Installed
- Loaded dynamically
- Invoked

Source is only a knowledge resource for the Creation Engine.
