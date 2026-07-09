flowchart LR
  Client[Client API<br/>application consommatrice] --> APIM[Azure API Management<br/>contrat /gemini]

  subgraph Azure[Azure]
    APIM --> Policy[Policies APIM<br/>Entra ID, allowlist modeles,<br/>secret applicatif ou WIF]
    Policy --> VNet[Azure VNet<br/>integration reseau possible]
    ER[ExpressRoute<br/>circuit prive]
  end

  subgraph PrivateLink[Connectivite privee inter-cloud]
    VNet --> ER
    ER -. peering / provider exchange .-> Interconnect[Google Cloud Interconnect<br/>]
  end

  subgraph GCP[Google Cloud]
    Interconnect --> VPC[GCP VPC<br/>routage prive]
    VPC -. acces prive backend .-> LB[Load Balancer GCP<br/>frontal backend prive]
    LB --> Run[Cloud Run<br/>FastAPI Gemini wrapper]
    Policy -->|chemin POC valide<br/>HTTPS + X-Internal-Api-Key| LB
    Policy -. chemin WIF cible .-> STS[Google STS<br/>Workload Identity Federation]
    STS -. generateIdToken .-> IAMCreds[IAM Credentials]
    IAMCreds -. ID token Cloud Run .-> Run
    Run --> Vertex[Vertex AI Gemini<br/>aiplatform generate_content]
  end

  subgraph IaC[Infrastructure as Code]
    TFAZ[Terraform Azure] --> APIM
    TFGCP[Terraform GCP] --> Run
    TFGCP --> Vertex
    TFGCP --> STS
  end
