---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of what the bug is.

## Environment

- **voip-stack Version**: [e.g., v0.1.0-alpha]
- **macOS Version**: [e.g., macOS 14.0 Sonoma]
- **Mac Model**: [e.g., M1 MacBook Pro, M2 Mac Studio]
- **RAM**: [e.g., 16GB, 32GB]
- **libvirt Version**: [e.g., 9.0.0]
- **devstack-core Status**: [running/stopped, which profile]

## Component(s) Affected

Check all that apply:
- [ ] OpenSIPS
- [ ] Kamailio
- [ ] Asterisk
- [ ] FreeSWITCH
- [ ] RTPEngine
- [ ] Vault integration
- [ ] Database (PostgreSQL/TimescaleDB)
- [ ] Homer (SIP capture)
- [ ] Prometheus/Grafana monitoring
- [ ] Ansible provisioning
- [ ] libvirt VM management
- [ ] Documentation
- [ ] Other: ___________

## Steps to Reproduce

1. Go to '...'
2. Run command '...'
3. Observe error '...'
4. See issue

## Expected Behavior

What should happen?

## Actual Behavior

What actually happened?

## Logs

Please provide relevant logs (sanitize any sensitive information):

### OpenSIPS logs
```
# /var/log/opensips.log or docker logs
```

### Asterisk logs
```
# /var/log/asterisk/messages or docker logs
```

### RTPEngine logs
```
# journalctl -u rtpengine or docker logs
```

### Ansible output
```
# Output from ansible-playbook command
```

### SIPp output (if applicable)
```
# SIPp error messages or scenario output
```

## Configuration

Please provide relevant configuration (sanitize passwords/secrets):

### opensips.cfg (relevant sections)
```
# Paste relevant sections
```

### Asterisk pjsip.conf (relevant sections)
```
# Paste relevant sections
```

### .env file (sanitized)
```
# Paste relevant variables (NO REAL PASSWORDS)
```

## Network Topology

Describe your network setup:
- SIP VM IP: 192.168.64.10
- PBX VM IP: 192.168.64.30
- Media VM IP: 192.168.64.20
- External interface: [yes/no, which VMs]

## Additional Context

Add any other context about the problem here:
- Screenshots (if applicable)
- SIP traces (use Homer or sngrep output, sanitized)
- PCAP files (if available, sanitized)
- Timeline of events

## Possible Solution

If you have ideas on how to fix this, please share.

## Related Issues

Link any related issues here.
