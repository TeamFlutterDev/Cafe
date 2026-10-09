-- ============================================================
-- SUPABASE PENDING MIGRATIONS  (run when switching to Supabase)
-- ============================================================

-- 1. Create role_master table
CREATE TABLE IF NOT EXISTS role_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL,
  role_name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  description TEXT,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  can_view_dashboard BOOLEAN NOT NULL DEFAULT FALSE,
  can_create_bill BOOLEAN NOT NULL DEFAULT FALSE,
  can_edit_bill BOOLEAN NOT NULL DEFAULT FALSE,
  can_cancel_bill BOOLEAN NOT NULL DEFAULT FALSE,
  can_apply_discount BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_items BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_tables BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_reports BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_users BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_settings BOOLEAN NOT NULL DEFAULT FALSE,
  can_void_items BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_stock BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_roles BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, role_name)
);

-- 2. Add can_manage_roles column to user_permission
ALTER TABLE user_permission
  ADD COLUMN IF NOT EXISTS can_manage_roles BOOLEAN NOT NULL DEFAULT FALSE;

-- 3. Seed system roles for all existing companies
INSERT INTO role_master (
  company_id, role_name, display_name, description, is_system,
  can_view_dashboard, can_create_bill, can_edit_bill, can_cancel_bill,
  can_apply_discount, can_manage_items, can_manage_tables, can_view_reports,
  can_manage_users, can_manage_settings, can_void_items, can_manage_stock,
  can_manage_roles
)
SELECT
  c.id,
  r.role_name, r.display_name, r.description, TRUE,
  r.can_view_dashboard, r.can_create_bill, r.can_edit_bill, r.can_cancel_bill,
  r.can_apply_discount, r.can_manage_items, r.can_manage_tables, r.can_view_reports,
  r.can_manage_users, r.can_manage_settings, r.can_void_items, r.can_manage_stock,
  r.can_manage_roles
FROM company c
CROSS JOIN (VALUES
  ('admin',          'Admin',          'Full system access',          TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE),
  ('manager',        'Manager',        'Manage operations & reports', TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  FALSE, FALSE, TRUE,  FALSE),
  ('staff',          'Staff',          'Billing and table service',   FALSE, TRUE,  TRUE,  FALSE, TRUE,  FALSE, TRUE,  TRUE,  FALSE, FALSE, FALSE, FALSE, FALSE),
  ('kitchen_master', 'Kitchen Master', 'Kitchen display & KOTs',      FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE, FALSE, FALSE)
) AS r(
  role_name, display_name, description,
  can_view_dashboard, can_create_bill, can_edit_bill, can_cancel_bill,
  can_apply_discount, can_manage_items, can_manage_tables, can_view_reports,
  can_manage_users, can_manage_settings, can_void_items, can_manage_stock,
  can_manage_roles
)
ON CONFLICT (company_id, role_name) DO NOTHING;
