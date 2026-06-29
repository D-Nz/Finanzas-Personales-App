-- ================================================================
--  FINANZAS PERSONALES — Esquema completo Supabase
--  Ejecutar en: Supabase → SQL Editor → New Query → Run
--  Orden: ejecutar de arriba hacia abajo completo
-- ================================================================

-- ── Extensión para UUIDs ──────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- 1. PERFILES DE USUARIO
-- ================================================================
CREATE TABLE IF NOT EXISTS perfiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre      TEXT NOT NULL,
  apellido    TEXT,
  moneda      TEXT NOT NULL DEFAULT 'USD',
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 2. OBLIGACIONES COMPARTIDAS (préstamos entre usuarios)
-- ================================================================
CREATE TABLE IF NOT EXISTS obligaciones (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titular_id      UUID NOT NULL REFERENCES perfiles(id),   -- quien prestó / pagó
  deudor_id       UUID NOT NULL REFERENCES perfiles(id),   -- quien debe
  nombre          TEXT NOT NULL,
  descripcion     TEXT DEFAULT '',
  monto_total     NUMERIC(12,2) NOT NULL DEFAULT 0,
  valor_cuota     NUMERIC(12,2),
  num_cuotas      INTEGER,
  fecha_inicio    DATE,
  estado          TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','cerrada','pausada')),
  notas           TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 3. CUOTAS / PAGOS DE OBLIGACIONES
-- ================================================================
CREATE TABLE IF NOT EXISTS cuotas (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  obligacion_id   UUID NOT NULL REFERENCES obligaciones(id) ON DELETE CASCADE,
  numero          INTEGER,
  concepto        TEXT DEFAULT '',
  fecha_prog      DATE,
  fecha_pago      DATE,
  valor_esperado  NUMERIC(12,2) DEFAULT 0,
  valor_pagado    NUMERIC(12,2) DEFAULT 0,
  estado          TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pagado','pendiente','revisar')),
  nota            TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 4. PRESUPUESTO MENSUAL (por usuario y mes)
-- ================================================================
CREATE TABLE IF NOT EXISTS presupuestos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id      UUID NOT NULL REFERENCES perfiles(id),
  anio            INTEGER NOT NULL,
  mes             INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ingreso_total   NUMERIC(12,2) DEFAULT 0,
  pct_necesidades NUMERIC(5,2) DEFAULT 50,
  pct_deseos      NUMERIC(5,2) DEFAULT 30,
  pct_ahorros     NUMERIC(5,2) DEFAULT 20,
  notas           TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (usuario_id, anio, mes)
);

-- ================================================================
-- 5. INGRESOS
-- ================================================================
CREATE TABLE IF NOT EXISTS ingresos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id      UUID NOT NULL REFERENCES perfiles(id),
  anio            INTEGER NOT NULL,
  mes             INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
  concepto        TEXT NOT NULL,
  valor           NUMERIC(12,2) NOT NULL DEFAULT 0,
  fecha           DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 6. GASTOS
-- ================================================================
CREATE TABLE IF NOT EXISTS gastos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id      UUID NOT NULL REFERENCES perfiles(id),
  anio            INTEGER NOT NULL,
  mes             INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
  fecha           DATE,
  concepto        TEXT NOT NULL,
  valor           NUMERIC(12,2) NOT NULL DEFAULT 0,
  categoria       TEXT DEFAULT 'Sin categoría',
  tipo            TEXT DEFAULT 'variable' CHECK (tipo IN ('fijo','variable')),
  naturaleza      TEXT DEFAULT 'Necesidades' CHECK (naturaleza IN ('Necesidades','Deseos','Ahorros')),
  fuente          TEXT DEFAULT 'manual' CHECK (fuente IN ('manual','importado')),
  banco_origen    TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 7. OBJETIVOS DE AHORRO
-- ================================================================
CREATE TABLE IF NOT EXISTS ahorros (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id      UUID NOT NULL REFERENCES perfiles(id),
  nombre          TEXT NOT NULL,
  objetivo        NUMERIC(12,2) NOT NULL DEFAULT 0,
  acumulado       NUMERIC(12,2) NOT NULL DEFAULT 0,
  fecha_inicio    DATE,
  fecha_meta      DATE,
  color           TEXT DEFAULT '#10b981',
  activo          BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 8. APORTES A AHORROS
-- ================================================================
CREATE TABLE IF NOT EXISTS aportes_ahorro (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ahorro_id       UUID NOT NULL REFERENCES ahorros(id) ON DELETE CASCADE,
  fecha           DATE NOT NULL DEFAULT CURRENT_DATE,
  valor           NUMERIC(12,2) NOT NULL DEFAULT 0,
  nota            TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 9. EXTRACTOS IMPORTADOS (líneas de estado de cuenta)
-- ================================================================
CREATE TABLE IF NOT EXISTS extractos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id      UUID NOT NULL REFERENCES perfiles(id),
  banco           TEXT NOT NULL,
  tarjeta_ref     TEXT DEFAULT '',
  fecha_tx        DATE,
  concepto        TEXT NOT NULL,
  tipo_op         TEXT DEFAULT '',
  valor           NUMERIC(12,2) NOT NULL DEFAULT 0,
  categoria       TEXT DEFAULT 'Sin categoría',
  estado          TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente','registrado','descartado')),
  mes_periodo     INTEGER,
  anio_periodo    INTEGER,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- 10. INVITACIONES ENTRE USUARIOS (para deudas compartidas)
-- ================================================================
CREATE TABLE IF NOT EXISTS invitaciones (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  remitente_id    UUID NOT NULL REFERENCES perfiles(id),
  destinatario_email TEXT NOT NULL,
  obligacion_id   UUID REFERENCES obligaciones(id),
  estado          TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente','aceptada','rechazada')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- TRIGGERS: updated_at automático
-- ================================================================
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_perfiles_updated_at
  BEFORE UPDATE ON perfiles
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER trg_obligaciones_updated_at
  BEFORE UPDATE ON obligaciones
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- Auto-crear perfil al registrarse
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO perfiles (id, nombre, apellido)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'apellido', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================================

ALTER TABLE perfiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE obligaciones    ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuotas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE presupuestos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingresos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE gastos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ahorros         ENABLE ROW LEVEL SECURITY;
ALTER TABLE aportes_ahorro  ENABLE ROW LEVEL SECURITY;
ALTER TABLE extractos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitaciones    ENABLE ROW LEVEL SECURITY;

-- Perfiles: cada uno ve/edita el suyo
CREATE POLICY "perfil_select" ON perfiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "perfil_update" ON perfiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "perfil_insert" ON perfiles FOR INSERT WITH CHECK (auth.uid() = id);
-- Ver perfil básico de otros (para mostrar nombres en deudas compartidas)
CREATE POLICY "perfil_select_otros" ON perfiles FOR SELECT
  USING (id IN (
    SELECT titular_id FROM obligaciones WHERE deudor_id = auth.uid()
    UNION
    SELECT deudor_id FROM obligaciones WHERE titular_id = auth.uid()
  ));

-- Obligaciones: titular y deudor pueden ver; solo titular puede modificar
CREATE POLICY "obl_select" ON obligaciones FOR SELECT
  USING (titular_id = auth.uid() OR deudor_id = auth.uid());
CREATE POLICY "obl_insert" ON obligaciones FOR INSERT
  WITH CHECK (titular_id = auth.uid());
CREATE POLICY "obl_update" ON obligaciones FOR UPDATE
  USING (titular_id = auth.uid());
CREATE POLICY "obl_delete" ON obligaciones FOR DELETE
  USING (titular_id = auth.uid());

-- Cuotas: acceso via obligación
CREATE POLICY "cuota_select" ON cuotas FOR SELECT
  USING (obligacion_id IN (
    SELECT id FROM obligaciones WHERE titular_id = auth.uid() OR deudor_id = auth.uid()
  ));
CREATE POLICY "cuota_insert" ON cuotas FOR INSERT
  WITH CHECK (obligacion_id IN (
    SELECT id FROM obligaciones WHERE titular_id = auth.uid()
  ));
CREATE POLICY "cuota_update" ON cuotas FOR UPDATE
  USING (obligacion_id IN (
    SELECT id FROM obligaciones WHERE titular_id = auth.uid()
  ));
CREATE POLICY "cuota_delete" ON cuotas FOR DELETE
  USING (obligacion_id IN (
    SELECT id FROM obligaciones WHERE titular_id = auth.uid()
  ));

-- Datos personales: solo el propietario
CREATE POLICY "presup_all"  ON presupuestos   FOR ALL USING (usuario_id = auth.uid());
CREATE POLICY "ingreso_all" ON ingresos       FOR ALL USING (usuario_id = auth.uid());
CREATE POLICY "gasto_all"   ON gastos         FOR ALL USING (usuario_id = auth.uid());
CREATE POLICY "ahorro_all"  ON ahorros        FOR ALL USING (usuario_id = auth.uid());
CREATE POLICY "extracto_all" ON extractos     FOR ALL USING (usuario_id = auth.uid());

-- Aportes ahorro: via ahorros
CREATE POLICY "aporte_all" ON aportes_ahorro FOR ALL
  USING (ahorro_id IN (SELECT id FROM ahorros WHERE usuario_id = auth.uid()));

-- Invitaciones
CREATE POLICY "inv_select" ON invitaciones FOR SELECT
  USING (remitente_id = auth.uid() OR destinatario_email = (
    SELECT email FROM auth.users WHERE id = auth.uid()
  ));
CREATE POLICY "inv_insert" ON invitaciones FOR INSERT WITH CHECK (remitente_id = auth.uid());
CREATE POLICY "inv_update" ON invitaciones FOR UPDATE
  USING (remitente_id = auth.uid() OR destinatario_email = (
    SELECT email FROM auth.users WHERE id = auth.uid()
  ));

-- ================================================================
-- VISTA UTILITARIA: resumen de obligaciones con nombres
-- ================================================================
CREATE OR REPLACE VIEW v_obligaciones AS
SELECT
  o.*,
  pt.nombre || ' ' || COALESCE(pt.apellido,'') AS titular_nombre,
  pd.nombre || ' ' || COALESCE(pd.apellido,'') AS deudor_nombre,
  (
    SELECT COALESCE(SUM(valor_pagado),0)
    FROM cuotas WHERE obligacion_id = o.id AND estado = 'pagado'
  ) AS total_pagado,
  o.monto_total - (
    SELECT COALESCE(SUM(valor_pagado),0)
    FROM cuotas WHERE obligacion_id = o.id AND estado = 'pagado'
  ) AS saldo_pendiente
FROM obligaciones o
JOIN perfiles pt ON pt.id = o.titular_id
JOIN perfiles pd ON pd.id = o.deudor_id;
