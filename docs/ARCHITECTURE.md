              ┌──────────────────────────┐
              │       Users / UI         │
              └────────────┬─────────────┘
                           │ HTTP
                           ▼
              ┌──────────────────────────┐
              │  Web App (Cloud Run)     │
              │  - Serves pages / API    │
              │  - Enqueues jobs         │
              └───┬────────────┬─────────┘
     reads/writes│            │enqueue
                ▼             ▼
      ┌────────────────┐  ┌───────────────┐
      │  Cloud SQL     │  │   Queue Layer │
      │  (Postgres)    │  │ (Pub/Sub/Redis)│
      └──────┬─────────┘  └──────┬────────┘
             │                    │ dequeue
             │                    ▼
             │            ┌──────────────────┐
             │            │ Queue Workers     │
             │            │ (Cloud Run jobs)  │
             │            │ - process jobs    │
             │            │ - call externals  │
             │            └───┬──────────┬────┘
             │                │          │
    cache    │                │          │store files
             ▼                │          ▼
      ┌─────────────┐         │   ┌─────────────────┐
      │ Redis /     │◀────────┘   │ Cloud Storage    │
      │ Memorystore │             │ (file attachments)│
      └─────────────┘             └─────────────────┘
             │
             │
             ▼
     (fast lookups / sessions)