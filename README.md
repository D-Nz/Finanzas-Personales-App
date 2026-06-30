# Finanzas Personales
**Control inteligente de tus finanzas** — Plataforma web multi-usuario

Desarrollado por **D.A.N.C.** · Stack: HTML + Supabase (PostgreSQL) · Hosting: GitHub Pages

---

## Estructura del repositorio

```
/
├── index.html          ← App completa (frontend SPA)
├── supabase_schema.sql ← Schema de base de datos (ejecutar 1 vez en Supabase)
└── README.md
```

## Configuración inicial (orden obligatorio)

### 1. Supabase — Crear tablas

1. Ve a [supabase.com](https://supabase.com) → tu proyecto → **SQL Editor**
2. Abre `supabase_schema.sql` y copia todo el contenido
3. Pégalo en el editor SQL y haz clic en **Run**
4. Verifica que aparezcan las tablas en **Table Editor**

**Tablas que se crean:**
- `perfiles` — datos de cada usuario
- `obligaciones` — préstamos/deudas entre usuarios
- `cuotas` — pagos programados de cada obligación
- `presupuestos` — configuración 50/30/20 por mes
- `ingresos` — ingresos mensuales por usuario
- `gastos` — gastos mensuales (manuales o importados)
- `ahorros` — objetivos de ahorro
- `aportes_ahorro` — movimientos hacia cada ahorro
- `extractos` — líneas de estados de cuenta importados
- `invitaciones` — invitaciones entre usuarios para obligaciones compartidas

### 2. Supabase — Configurar Auth

1. **Authentication → Providers** → Asegurar que **Email** esté habilitado
2. **Authentication → Email Templates** → Personalizar si deseas (opcional)
3. **Authentication → URL Configuration** → Agregar tu URL de GitHub Pages:
   ```
   https://*****
   ```
   en **Site URL** y también en **Redirect URLs**

### 3. GitHub Pages — Activar hosting

1. Ve a tu repositorio: `https://github.com/D-Nz/Finanzas-Personales-App`
2. **Settings → Pages**
3. Source: **Deploy from a branch**
4. Branch: `main` → `/root` → **Save**
5. En 2-3 minutos tu app estará en: `******`

### 4. Subir archivos a GitHub

```bash
# Si es la primera vez
git init
git add index.html supabase_schema.sql README.md
git commit -m "feat: lanzamiento inicial Finanzas Personales"
git branch -M main
git remote add origin https://github.com/D-Nz/Finanzas-Personales-App.git
git push -u origin main

# Para actualizaciones futuras
git add index.html
git commit -m "feat: descripción del cambio"
git push
```

---

## Funcionalidades

| Módulo | Descripción |
|---|---|
| **Resumen** | Dashboard con ingresos, gastos, balance y obligaciones activas del mes |
| **Presupuesto** | Regla 50/30/20 configurable, registro de ingresos y gastos con categorías |
| **Obligaciones** | Préstamos compartidos entre usuarios — cada uno ve su rol (titular/deudor) |
| **Ahorros** | Objetivos de ahorro con progreso visual y registro de aportes |
| **Extractos** | Importación de estados de cuenta PDF (PacifiCard, Diners, Discover, Pichincha) |
| **Bola de Nieve** | Simulador de amortización acelerada ordenado de menor a mayor deuda |

---

## Seguridad (Row Level Security)

Cada usuario solo ve y modifica sus propios datos. Las obligaciones compartidas aplican:
- **Titular** (quien prestó): ve monto total, saldo, historial completo, registra pagos
- **Deudor** (quien debe): ve solo lo que le corresponde, sin acceso a edición

Las políticas RLS se configuran automáticamente al ejecutar `supabase_schema.sql`.
---

## Soporte de bancos ecuatorianos en importación

| Banco | Formato | Estado |
|---|---|---|
| B* d* P* (P*) | PDF digital | ✅ Soportado |
| D* C* | PDF digital | ✅ Soportado |
| D* (D*) | PDF digital | ✅ Soportado |
| B* P* | PDF digital | ✅ Soportado |
| Cualquier banco | Excel/CSV | 🔄 Próximamente |

---

*D · A · N · C — Finanzas Personales v1.0*
