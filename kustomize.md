# Kustomize

## Todo Applicaiton

Sample todo applicaition
- Quarkus Native
- PostgreSQL Datababase

```
├── base
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── service-monitor.yaml
│   ├── todo-db.yaml
│   └── todo.yaml
└── overlays
    └── dev
        ├── kustomization.yaml
        └── todo.yaml
```

- Create Todo Application with overlays *dev*

```bash
oc apply -k manifests/todo-kustomize/overlays/dev
```

## Frontend/Backend Applicaiton

Sample Frontend/Backend applicaition

```
.
├── base
│   ├── backend-service.yaml
│   ├── backend.yaml
│   ├── demo-rolebinding.yaml
│   ├── frontend-service.yaml
│   ├── frontend.yaml
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   └── route.yaml
└── overlays
    ├── dev
    │   ├── backend.yaml
    │   ├── frontend.yaml
    │   └── kustomization.yaml
    └── prod
        ├── backend.yaml
        ├── frontend.yaml
        └── kustomization.yaml
```

- Create Todo Application with overlays *dev*

```bash
oc apply -k manifests/apps-kustomize/overlays/dev
```