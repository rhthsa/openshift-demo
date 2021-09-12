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
oc apply -f manifests/todo-kustomize/overlays/dev
```