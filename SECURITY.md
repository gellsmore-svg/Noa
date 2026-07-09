# Security Policy

## Reporting A Vulnerability

Please do not open a public issue for sensitive security problems.

Report suspected vulnerabilities privately through GitHub's private vulnerability
reporting for this repository, or contact the repository owner directly through
the GitHub account listed on the project.

## Scope

Noa is an orchestration and runtime scaffold. Security-sensitive areas include:

- install and upgrade scripts,
- `.env` handling and generated config,
- systemd service templates,
- GitHub issue publishing workflows,
- live observer report generation,
- public lockfiles and dependency pins.

Do not include secrets, customer data, private prompts, raw trace exports, local
database files, or generated observer reports in vulnerability reports unless
they have been redacted.

## Supported Version

The latest public release and `main` are the supported surfaces for security
fixes.
