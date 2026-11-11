-- ====================================================================
-- R-II BUILDERS, INC. • INVENTORY & WAREHOUSE MANAGEMENT SYSTEM
-- COMPLETE STANDALONE & MASTER REGISTRY SCHEMA FOR SUPABASE / POSTGRESQL
-- Idempotent script: safe to run on fresh or existing Supabase projects
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- PART 1: DIRECTORY & MASTER DATA REGISTRIES (5 TABLES)
-- ====================================================================

-- 1. PROJECTS REGISTRY (No | Project Name | Location)
CREATE TABLE IF NOT EXISTS projects_registry (
    id TEXT PRIMARY KEY,
    project_name TEXT NOT NULL,
    location TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. DEPARTMENT REGISTRY (No. | Department)
CREATE TABLE IF NOT EXISTS departments_registry (
    id TEXT PRIMARY KEY,
    department_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. SUPPLIER REGISTRY (No. | Supplier Name | Address | TIN)
CREATE TABLE IF NOT EXISTS suppliers_registry (
    id TEXT PRIMARY KEY,
    supplier_name TEXT NOT NULL,
    address TEXT,
    tin TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. ITEMS REGISTRY (No. | Item Code | Description | UOM | Unit Cost)
CREATE TABLE IF NOT EXISTS items_registry (
    id TEXT PRIMARY KEY,
    item_code TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    uom TEXT DEFAULT 'PCS',
    unit_cost NUMERIC(12,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. CHART OF ACCOUNTS REGISTRY (No. | Account Code | Account Title | Category)
CREATE TABLE IF NOT EXISTS chart_of_accounts_registry (
    id TEXT PRIMARY KEY,
    account_code TEXT NOT NULL,
    account_title TEXT NOT NULL,
    category TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ====================================================================
-- PART 2: OPERATIONAL & INVENTORY TABLES (6 TABLES)
-- ====================================================================

-- 6. SUPPLIES REQUESTS & WAREHOUSE ISSUANCES
CREATE TABLE IF NOT EXISTS supplies_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference_number VARCHAR(50),
    reference VARCHAR(50),
    department VARCHAR(100) NOT NULL,
    requestor_name VARCHAR(150),
    requester VARCHAR(150),
    date_needed DATE,
    purpose TEXT,
    requested_items TEXT,
    status VARCHAR(50) DEFAULT 'Pending',
    submitted_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    issued_date TIMESTAMP WITH TIME ZONE,
    remarks TEXT,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS reference VARCHAR(50);
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS reference_number VARCHAR(50);
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS requestor_name VARCHAR(150);
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS requester VARCHAR(150);
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS date_needed DATE;
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS purpose TEXT;
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS requested_items TEXT;
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS submitted_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS issued_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS remarks TEXT;
ALTER TABLE supplies_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 7. SUPPLIES ITEMS (LINE ITEMS LINKED TO SUPPLIES REQUESTS)
CREATE TABLE IF NOT EXISTS supplies_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES supplies_requests(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    quantity NUMERIC(12,2) DEFAULT 1,
    purpose TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. PURCHASE ORDERS (PO)
CREATE TABLE IF NOT EXISTS purchase_orders (
    id TEXT PRIMARY KEY,
    po_no VARCHAR(50) UNIQUE NOT NULL,
    prf_no VARCHAR(50),
    date DATE DEFAULT CURRENT_DATE,
    project VARCHAR(150) NOT NULL,
    department VARCHAR(100),
    supplier_name VARCHAR(150) NOT NULL,
    items JSONB DEFAULT '[]'::jsonb,
    items_desc TEXT,
    grand_total NUMERIC(15,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'Approved',
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS items_desc TEXT;
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS remarks TEXT;

-- 9. RECEIVING REPORTS (MRR)
CREATE TABLE IF NOT EXISTS receiving_reports (
    id TEXT PRIMARY KEY,
    rr_no VARCHAR(50) NOT NULL,
    report_date DATE DEFAULT CURRENT_DATE,
    po_no VARCHAR(50),
    prf_no VARCHAR(50),
    supplier_name VARCHAR(150) NOT NULL,
    project VARCHAR(150),
    department VARCHAR(100),
    item_type VARCHAR(150),
    expense_account VARCHAR(150),
    sub_account VARCHAR(150),
    dr_no VARCHAR(50),
    items JSONB DEFAULT '[]'::jsonb,
    items_desc TEXT,
    total_amount NUMERIC(15,2) DEFAULT 0.00,
    condition VARCHAR(100) DEFAULT 'Accepted in Good Condition',
    received_by VARCHAR(150),
    inspector VARCHAR(150),
    budget_from VARCHAR(100),
    is_2025_stock BOOLEAN DEFAULT FALSE,
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE receiving_reports ADD COLUMN IF NOT EXISTS project VARCHAR(150);
ALTER TABLE receiving_reports ADD COLUMN IF NOT EXISTS item_type VARCHAR(150);
ALTER TABLE receiving_reports ADD COLUMN IF NOT EXISTS items_desc TEXT;
ALTER TABLE receiving_reports ADD COLUMN IF NOT EXISTS condition VARCHAR(100) DEFAULT 'Accepted in Good Condition';
ALTER TABLE receiving_reports ADD COLUMN IF NOT EXISTS inspector VARCHAR(150);
ALTER TABLE receiving_reports ADD COLUMN IF NOT EXISTS dr_no VARCHAR(50);

-- 10. MATERIAL ISSUANCE SLIPS (MIS)
CREATE TABLE IF NOT EXISTS material_issuances (
    id TEXT PRIMARY KEY,
    mis_no VARCHAR(50) NOT NULL,
    issue_date DATE DEFAULT CURRENT_DATE,
    department VARCHAR(150) NOT NULL,
    issued_to VARCHAR(150) NOT NULL,
    purpose TEXT,
    expense_account VARCHAR(150),
    tagged_equipment_plate VARCHAR(50),
    items JSONB DEFAULT '[]'::jsonb,
    items_desc TEXT,
    total_qty NUMERIC(12,2) DEFAULT 1,
    total_amount NUMERIC(15,2) DEFAULT 0.00,
    linked_supplies_id TEXT,
    status VARCHAR(50) DEFAULT 'ISSUED',
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE material_issuances ADD COLUMN IF NOT EXISTS tagged_equipment_plate VARCHAR(50);
ALTER TABLE material_issuances ADD COLUMN IF NOT EXISTS items_desc TEXT;
ALTER TABLE material_issuances ADD COLUMN IF NOT EXISTS linked_supplies_id TEXT;

-- 11. ON-HAND INVENTORY & STOCK MASTER
CREATE TABLE IF NOT EXISTS on_hand_inventory (
    item_id VARCHAR(100) PRIMARY KEY,
    item_code VARCHAR(50),
    description TEXT NOT NULL,
    expense_account VARCHAR(150),
    category VARCHAR(150) DEFAULT 'General Supplies',
    uom VARCHAR(30) DEFAULT 'PCS',
    warehouse_location VARCHAR(150) DEFAULT 'Central Warehouse - North Harbor',
    stock_2025_qty NUMERIC(12,2) DEFAULT 0.00,
    deliveries_2026_qty NUMERIC(12,2) DEFAULT 0.00,
    total_received_qty NUMERIC(12,2) DEFAULT 0.00,
    total_issued_qty NUMERIC(12,2) DEFAULT 0.00,
    on_hand_qty NUMERIC(12,2) DEFAULT 0.00,
    unit_cost NUMERIC(12,2) DEFAULT 0.00,
    on_hand_value NUMERIC(15,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'In Stock',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ====================================================================
-- PART 3: ROW LEVEL SECURITY (RLS) POLICIES (IDEMPOTENT)
-- ====================================================================
ALTER TABLE projects_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE items_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplies_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplies_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE material_issuances ENABLE ROW LEVEL SECURITY;
ALTER TABLE on_hand_inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read/write for projects_registry" ON projects_registry;
CREATE POLICY "Allow public read/write for projects_registry" ON projects_registry FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for departments_registry" ON departments_registry;
CREATE POLICY "Allow public read/write for departments_registry" ON departments_registry FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for suppliers_registry" ON suppliers_registry;
CREATE POLICY "Allow public read/write for suppliers_registry" ON suppliers_registry FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for items_registry" ON items_registry;
CREATE POLICY "Allow public read/write for items_registry" ON items_registry FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for chart_of_accounts_registry" ON chart_of_accounts_registry;
CREATE POLICY "Allow public read/write for chart_of_accounts_registry" ON chart_of_accounts_registry FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for supplies_requests" ON supplies_requests;
CREATE POLICY "Allow public read/write for supplies_requests" ON supplies_requests FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for supplies_items" ON supplies_items;
CREATE POLICY "Allow public read/write for supplies_items" ON supplies_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for purchase_orders" ON purchase_orders;
CREATE POLICY "Allow public read/write for purchase_orders" ON purchase_orders FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for receiving_reports" ON receiving_reports;
CREATE POLICY "Allow public read/write for receiving_reports" ON receiving_reports FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for material_issuances" ON material_issuances;
CREATE POLICY "Allow public read/write for material_issuances" ON material_issuances FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write for on_hand_inventory" ON on_hand_inventory;
CREATE POLICY "Allow public read/write for on_hand_inventory" ON on_hand_inventory FOR ALL USING (true) WITH CHECK (true);
