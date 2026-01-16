# Networking Module

Creates VPC network infrastructure for Invoice Ninja on GCP.

## Resources Created

- VPC network
- Subnet for Serverless VPC Connector
- Serverless VPC Access Connector (for Cloud Run → Cloud SQL private connection)
- Private IP range reservation for Cloud SQL
- Private VPC peering connection
- Firewall rules for health checks

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"
  
  project_id = "your-project-id"
  region     = "us-central1"
  env        = "dev"
}
```

## Learning Resources

- [Serverless VPC Access](https://cloud.google.com/vpc/docs/configure-serverless-vpc-access)
- [Private Services Access](https://cloud.google.com/vpc/docs/private-services-access)
- [VPC Networks](https://cloud.google.com/vpc/docs/vpc)


┌─────────────────────────────────────────┐
│  Internet (Public)                      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────┐
│  Cloud Run (Web App)     │ ← Has public IP
│  - Serverless            │
│  - Autoscales            │
└──────────┬───────────────┘
           │
           │ [Serverless VPC Connector]
           │ (The Bridge)
           ▼
┌─────────────────────────────────────────┐
│         Your VPC (Private House)        │
│  ┌───────────────────────────────────┐  │
│  │ Subnet (Connector Room)           │  │
│  │ 10.8.0.0/28                       │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Cloud SQL (Private)               │  │
│  │ 10.10.x.x (via VPC Peering)      │  │
│  │ - No public IP                    │  │
│  │ - Only accessible from VPC        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [Firewall: Allow health checks only]  │
└─────────────────────────────────────────┘