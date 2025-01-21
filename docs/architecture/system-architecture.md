# System Architecture

## High-Level Architecture Diagram

```plantuml
@startuml
!define DARKBLUE
!includeurl https://raw.githubusercontent.com/Drakemor/RedDress-PlantUML/master/style.puml

title Microservices Architecture Overview

package "Frontend Layer" {
    [Angular Application] as Frontend
    note right: Single Page Application\nResponsive Design
}

package "API Gateway" {
    [Kong API Gateway] as Gateway
    note right: Request Routing\nAuthentication\nRate Limiting
}

package "Microservices" {
    [User Service] as UserService
    [Authentication Service] as AuthService
    [Data Processing Service] as DataService
    note right: Independent\nScalable Services
}

database "Database Cluster" {
    [PostgreSQL Primary] as PrimaryDB
    [PostgreSQL Replica] as ReplicaDB
    note right: Multi-Region\nHigh Availability
}

cloud "Monitoring & Observability" {
    [Prometheus] as Monitor
    [Grafana] as Dashboard
    [ELK Stack] as Logging
}

cloud "Cloud Infrastructure" {
    [AWS EKS] as Kubernetes
    [AWS Secret Manager] as SecretManager
}

Frontend --> Gateway: HTTPS Requests
Gateway --> UserService: Authenticated Requests
Gateway --> AuthService: Token Validation
Gateway --> DataService: Data Operations

UserService --> PrimaryDB: Read/Write
DataService --> ReplicaDB: Read Operations

Kubernetes .. UserService
Kubernetes .. AuthService
Kubernetes .. DataService

Monitor <-- UserService: Metrics
Monitor <-- AuthService: Performance Data
Dashboard <-- Monitor: Visualization
Logging <-- UserService: Logs

SecretManager --> AuthService: Credentials
SecretManager --> UserService: Configuration

@enduml