# Root Cause Analysis (RCA) Template

**Incident ID**: INC-YYYY-MM-DD-XXX  
**Date**: YYYY-MM-DD  
**Prepared By**: [Name, Role]  
**Reviewed By**: [Names]  
**Distribution**: Engineering Team, Leadership, Stakeholders

---

## Executive Summary

**One-paragraph summary of what happened, impact, and resolution.**

Example:
> On January 17, 2026, between 14:30-15:45 UTC, the Invoice Ninja production application experienced a complete service outage affecting all users. The root cause was database connection pool exhaustion triggered by a memory leak in the v2.5.0 deployment. The incident was resolved by rolling back to v2.4.8 and implementing connection pool monitoring. Total estimated revenue impact: $X,XXX. No data loss occurred.

---

## Incident Details

### Timeline

All times in UTC

| Time | Event | Who |
|------|-------|-----|
| 14:25 | v2.5.0 deployment completed | DevOps (automated) |
| 14:30 | First error logs appear | System |
| 14:32 | High error rate alert triggered | Monitoring |
| 14:33 | On-call engineer paged | PagerDuty |
| 14:35 | Incident acknowledged | @engineer-name |
| 14:37 | Investigation started - checking recent deployment | @engineer-name |
| 14:40 | Database connection pool identified as bottleneck | @engineer-name |
| 14:42 | SEV1 declared - all hands on deck | @engineer-name |
| 14:45 | Decision made to rollback deployment | @lead-engineer |
| 14:47 | Rollback initiated to v2.4.8 | @engineer-name |
| 14:52 | Rollback completed, monitoring recovery | @engineer-name |
| 14:55 | Error rate dropping, connections normalizing | System |
| 15:00 | Application health checks passing | System |
| 15:15 | Full service restored, monitoring for 30 min | @engineer-name |
| 15:45 | Incident declared resolved | @engineer-name |

**Total Duration**: 1 hour 15 minutes  
**Detection Time**: 2 minutes (first error to alert)  
**Response Time**: 1 minute (alert to acknowledgment)  
**Mitigation Time**: 15 minutes (decision to rollback completion)  
**Recovery Time**: 13 minutes (rollback to full recovery)

---

## Impact Assessment

### User Impact
- **Severity**: SEV1 - Complete Service Outage
- **Affected Users**: 100% (all users)
- **User-Facing Symptoms**:
  - Unable to log in
  - Timeout errors on all pages
  - "Service Unavailable" error messages

### Business Impact
- **Revenue Impact**: Estimated $X,XXX in lost transactions
- **Transaction Volume**: XX transactions failed/delayed
- **Customer Support**: XX support tickets created
- **Reputational Impact**: [Description]
- **SLA Breach**: [If applicable]

### Technical Impact
- **Systems Affected**:
  - Cloud Run: invoice-ninja-web (all instances)
  - Cloud SQL: invoiceninja-prod-db (connection pool)
  - Queue Workers: Unable to process jobs
- **Data Impact**: No data loss
- **Security Impact**: None

### SLO Impact
- **Availability SLO**: 99.9% target
  - Incident consumed XX% of monthly error budget
  - XX minutes remaining in error budget for month
- **Latency SLO**: 95% requests < 500ms
  - Met (no impact during uptime periods)

---

## Root Cause

### The Problem
A memory leak in the new OAuth implementation (v2.5.0) caused application containers to gradually consume more memory, leading to increased garbage collection pauses. This caused database queries to take longer, exhausting the connection pool within 5 minutes of deployment under production load.

### The 5 Whys

**1. Why did the service go down?**  
→ Database connection pool was exhausted, preventing new requests from connecting to the database.

**2. Why was the connection pool exhausted?**  
→ Application containers were holding database connections for extended periods (30-60 seconds instead of < 1 second).

**3. Why were connections held longer?**  
→ Application was experiencing frequent garbage collection pauses due to memory pressure.

**4. Why was there memory pressure?**  
→ A memory leak in the OAuth token caching implementation was accumulating objects without releasing them.

**5. Why wasn't the memory leak caught before production?**  
→ Load testing was performed for only 10 minutes, insufficient to detect the gradual memory buildup that manifested after 20+ minutes under production traffic levels.

### Contributing Factors

1. **Insufficient Testing**: Load tests ran for only 10 minutes; leak manifested after 20+ minutes
2. **Missing Monitoring**: No memory leak detection or connection pool utilization monitoring
3. **Rapid Deployment**: Deployed during business hours without gradual rollout
4. **No Canary**: 100% traffic immediately switched to new version
5. **Code Review Gap**: OAuth implementation not reviewed by senior engineers

---

## Resolution

### Immediate Fix
1. Rolled back deployment from v2.5.0 to v2.4.8
2. Database connections returned to normal within 5 minutes
3. Service fully restored in 13 minutes

### Verification
- Error rate dropped from 100% to < 0.1%
- Database connection pool utilization: 90% → 15%
- Response time returned to baseline (P95 < 400ms)
- No data corruption detected
- All health checks passing

---

## What Went Well

- ✅ **Fast Detection**: Alert triggered within 2 minutes of first errors
- ✅ **Quick Response**: Engineer acknowledged within 1 minute
- ✅ **Clear Runbook**: Rollback procedure was documented and followed successfully
- ✅ **Good Communication**: Regular updates posted to #incidents channel
- ✅ **Team Coordination**: Cross-functional team mobilized quickly
- ✅ **Preserved Data**: No data loss despite complete outage

---

## What Went Wrong

- ❌ **Insufficient Load Testing**: 10-minute test didn't catch 20+ minute leak
- ❌ **No Canary Deployment**: 100% traffic switched immediately
- ❌ **Business Hours Deployment**: Deployed at 2:30 PM (high traffic time)
- ❌ **Missing Monitoring**: No memory leak detection, no connection pool alerts
- ❌ **Code Review**: OAuth implementation not thoroughly reviewed
- ❌ **No Gradual Rollout**: Traffic split strategy not used

---

## Action Items

### Immediate (This Week)

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 1 | Fix memory leak in OAuth implementation | @dev-lead | 2026-01-19 | In Progress |
| 2 | Add connection pool monitoring & alerts | @devops-eng | 2026-01-18 | ✅ Done |
| 3 | Implement memory leak detection in CI/CD | @devops-eng | 2026-01-20 | In Progress |
| 4 | Update load testing duration to 60+ minutes | @qa-lead | 2026-01-19 | Not Started |

### Short-term (This Month)

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 5 | Implement canary deployment strategy | @devops-lead | 2026-01-31 | Not Started |
| 6 | Add memory profiling to staging environment | @dev-lead | 2026-01-25 | Not Started |
| 7 | Create deployment time windows policy | @engineering-mgr | 2026-01-24 | Not Started |
| 8 | Mandatory senior engineer review for auth code | @cto | 2026-01-22 | Not Started |
| 9 | Implement circuit breaker for database connections | @dev-lead | 2026-02-01 | Not Started |

### Long-term (This Quarter)

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 10 | Chaos engineering program | @sre-team | 2026-03-31 | Not Started |
| 11 | Automated performance regression testing | @qa-lead | 2026-02-28 | Not Started |
| 12 | Connection pool auto-scaling | @devops-lead | 2026-03-15 | Not Started |

---

## Lessons Learned

### Technical Lessons
1. **Load testing must match production duration and traffic patterns**
   - Minimum 60-minute load tests under realistic traffic
   - Include ramp-up, steady-state, and ramp-down phases
   - Monitor memory growth over time

2. **Canary deployments are critical**
   - Start with 10% traffic, gradually increase
   - Automated rollback on error threshold
   - Monitor key metrics during rollout

3. **Connection pool monitoring is essential**
   - Alert at 70% utilization
   - Track connection lifetime distribution
   - Monitor connection acquisition time

### Process Lessons
1. **Code review requirements need enforcement**
   - Authentication/authorization code requires two senior reviews
   - Establish review checklists for high-risk changes
   - Automated enforcement via GitLab

2. **Deployment timing matters**
   - Establish deployment windows (off-peak hours)
   - Require approval for business-hours deployments
   - Consider time zones for global users

3. **Monitoring gaps are incident risks**
   - Proactively identify missing monitoring
   - Treat monitoring as code requirement
   - Review dashboards during architecture review

---

## Follow-up

### RCA Review Meeting
- **Date**: 2026-01-18, 2:00 PM UTC
- **Attendees**: Engineering team, Product, Leadership
- **Agenda**:
  - Present RCA findings
  - Discuss action items and timeline
  - Assign owners for follow-up work
  - Vote on high-priority items

### Progress Tracking
- Action items tracked in: [JIRA/Linear/Project Management Tool]
- Weekly review in team standups
- Monthly report to leadership on status

### External Communication
- [x] Customer status page updated
- [x] Post-incident email sent to customers
- [x] Support team briefed on details
- [ ] Public blog post (if warranted)

---

## Supporting Evidence

### Logs & Metrics
- Error logs: [Link to Cloud Logging query]
- Monitoring dashboard: [Link to snapshot]
- Database metrics: [Link to Cloud SQL metrics]
- Deployment logs: [Link to GitLab CI/CD pipeline]

### Screenshots
- [Attach relevant screenshots of error spikes, metrics, etc.]

### Code References
- Memory leak: [Link to specific code commit/file]
- Fix: [Link to PR with fix]

---

## Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Incident Commander | [Name] | | |
| Engineering Manager | [Name] | | |
| CTO/VP Engineering | [Name] | | |

---

## Appendix

### Related Incidents
- INC-2026-01-03-052: Similar database connection issue (resolved)
- INC-2025-12-15-031: OAuth implementation bug (different root cause)

### Useful Commands Run During Incident
```bash
# Check error rate
gcloud monitoring time-series list --filter='...'

# View database connections
gcloud sql instances describe...

# Rollback deployment
gcloud run services update-traffic...
```

### Monitoring Improvements Implemented
- New alert: Database connection pool > 70%
- New dashboard: Memory utilization trend
- New metric: Connection acquisition time

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-17  
**Next Review**: After action item completion (2026-02-01)
