# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

Currently, only the latest alpha release (0.1.x) is actively supported for security updates.

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in voip-stack, please report it responsibly.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead:

1. **Email**: Create a private security advisory on GitHub
   - Go to: https://github.com/YourUsername/voip-stack/security/advisories/new
   - Provide detailed information about the vulnerability

2. **What to Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Affected versions
   - Suggested fix (if available)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Assessment**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 7 days
  - High: 14 days
  - Medium: 30 days
  - Low: 60 days

### Disclosure Policy

- We will work with you to understand and resolve the issue
- We will keep you informed of progress
- Once fixed, we will:
  - Release a patch
  - Publish a security advisory
  - Credit you (if desired) in the advisory

## Security Best Practices

### For Deployments

1. **Never commit secrets**
   - Use `.env` files (gitignored)
   - Store all secrets in Vault
   - Use AppRole authentication

2. **TLS/SRTP Mandatory**
   - Always enable TLS for SIP signaling
   - Always enable SRTP for media
   - Use Vault PKI for certificate management

3. **Network Isolation**
   - PBX VM has NO external interface
   - Only SIP proxy and media server exposed
   - Use firewall rules (Phase 2)

4. **Regular Updates**
   - Keep components updated
   - Monitor security advisories for:
     - OpenSIPS
     - Kamailio
     - Asterisk
     - FreeSWITCH
     - RTPEngine

5. **Secret Rotation**
   - Rotate database passwords (default: 90 days)
   - Rotate TLS certificates (default: 730 days)
   - Rotate AMI/ARI credentials (default: 180 days)

6. **Monitoring**
   - Enable Prometheus alerts
   - Monitor failed authentication attempts
   - Track unusual call patterns
   - Review logs regularly

### For Development

1. **Sanitize Before Committing**
   - Never commit real passwords
   - Use placeholders: `${VAULT_TOKEN}` not actual tokens
   - Use example IPs: `192.168.64.x` not real IPs
   - Sanitize logs and debugging output

2. **Use .env.example**
   - Never commit `.env` file
   - Update `.env.example` with new variables
   - Document all required secrets

3. **Test Security Features**
   - Run security test suite before PRs
   - Verify TLS/SRTP enforcement
   - Test authentication failures

## Known Security Considerations

### Phase 1 (Current)

- **Development/Test Focus**: Not production-hardened yet
- **No WAF**: Web Application Firewall planned for Phase 4
- **No IDS/IPS**: Intrusion detection planned for Phase 4
- **Basic Firewall**: Advanced rules planned for Phase 2
- **No Rate Limiting**: DOS protection planned for Phase 3

### Expected by Phase

**Phase 2**:
- Firewall rules per-VM
- HA/failover (no single point of failure)
- Encrypted backups

**Phase 3**:
- Rate limiting (anti-DOS)
- Failed auth tracking
- Anomaly detection

**Phase 4**:
- WAF integration
- IDS/IPS
- Security hardening audit
- Penetration testing

## Security Features

### Current (Phase 1)

- ✅ **Vault Integration**: All secrets in HashiCorp Vault
- ✅ **AppRole Authentication**: Production-grade auth
- ✅ **TLS/SRTP Support**: Encryption available
- ✅ **Vault PKI**: Automated certificate management
- ✅ **Database Isolation**: Separate databases per component
- ✅ **Least Privilege**: Per-VM Vault policies
- ✅ **No Root in Containers**: Docker security best practices

### Planned

- ⏳ **Secret Rotation** (Phase 1, Week 8)
- ⏳ **Firewall Rules** (Phase 2)
- ⏳ **Rate Limiting** (Phase 3)
- ⏳ **WAF** (Phase 4)
- ⏳ **IDS/IPS** (Phase 4)

## Common Vulnerabilities (VoIP-Specific)

### SIP Toll Fraud

**Risk**: Unauthorized calls to premium numbers

**Mitigations**:
- Authentication required for all calls
- Limit allowed destinations (dialplan)
- Monitor CDRs for unusual patterns
- Rate limiting (Phase 3)

### SIP Scanning/Enumeration

**Risk**: Attackers scanning for valid extensions

**Mitigations**:
- Do not reveal extension existence in error messages
- Rate limit REGISTER attempts (Phase 3)
- Monitor failed authentication (Phase 3)

### RTP Injection

**Risk**: Attackers injecting audio into calls

**Mitigations**:
- SRTP encryption (mandatory in Phase 1)
- RTP source validation
- Network isolation (internal/external interfaces)

### DOS Attacks

**Risk**: Overwhelming servers with SIP messages

**Mitigations**:
- Rate limiting (Phase 3)
- Connection limits
- Pike module in OpenSIPS (Phase 3)

## Compliance Notes

This project is designed to support compliance requirements, but compliance is the responsibility of the deploying organization.

**Supported frameworks** (with proper configuration):
- **PCI-DSS**: For payment card processing (requires additional hardening)
- **HIPAA**: For healthcare communications (encryption, audit logs)
- **GDPR**: For EU data privacy (data retention policies)

Consult with compliance experts for your specific use case.

## Resources

- **OpenSIPS Security**: https://www.opensips.org/Documentation/Tutorials-Security
- **Asterisk Security**: https://wiki.asterisk.org/wiki/display/AST/Asterisk+Security
- **VoIP Security**: https://www.voip-info.org/security/
- **Vault Security**: https://www.vaultproject.io/docs/internals/security

## Contact

For security questions: Use GitHub Security Advisories

For general questions: Open a regular GitHub issue

---

**Last Updated**: 2025-10-29
