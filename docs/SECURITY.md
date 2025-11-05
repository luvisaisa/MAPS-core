# Security Policy

## Supported Versions

Currently supported versions for security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.7.x   | :white_check_mark: |
| 0.6.x   | :white_check_mark: |
| < 0.6   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in MAPS, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Email security concerns to: isa.lucia.sch@gmail.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you to address the issue.

## Security Best Practices

### API Deployment

- Configure CORS origins restrictively
- Use HTTPS in production
- Implement rate limiting
- Set appropriate file upload limits
- Enable authentication for sensitive endpoints

### File Processing

- Validate file types before processing
- Limit file sizes to prevent DoS
- Sanitize file names
- Use temporary directories for uploads
- Clean up temporary files after processing

### Database

- Use parameterized queries (SQLAlchemy handles this)
- Limit database connection pool sizes
- Use read-only connections where possible
- Enable database encryption at rest
- Regular backups

### Dependencies

- Keep dependencies up to date
- Review dependency licenses
- Use virtual environments
- Pin dependency versions in production

## Known Security Considerations

### XML Processing

- External entity expansion disabled by default in lxml
- DTD processing disabled
- Network access disabled during parsing

### File Uploads

- Maximum file size enforced (configurable)
- File type validation
- Temporary file cleanup
- No arbitrary file execution

### API

- Input validation via Pydantic
- Error messages don't leak sensitive info
- Request size limits enforced
- Logging doesn't include sensitive data

## Security Updates

Security patches will be released as soon as possible and announced in:

- CHANGELOG.md
- GitHub releases
- Security advisories (if applicable)
