# R-II BUILDERS, INC.
## Inventory & Warehouse Management System (WMS)
*Standalone Module • Part of the Leo WorkSuite Enterprise Ecosystem*

---

### Overview
This folder contains the dedicated **Inventory & Warehouse Management System** for **R-II Builders, Inc.**, decoupled from the main Admin Management System into a standalone operational portal while preserving synchronized fiscal and operational records.

Built with the exact **PMIS / Admin Management visual theme** (Navy Blue `#1E355F`, Gold Accent `#FCAE16`, clean white sidebar with navy capsule active states, and dark/light mode toggle), this module covers all 5 core warehouse and material handling functions:

1. **Warehouse Operations Dashboard**: Live stock valuation, storage warehouse status, inventory turnover metrics, low-stock reorder priority watchlists, and recent receipts/issuances.
2. **Supplies Request & Issuance**: Approval workflows for departmental requisitions, status tagging (*Pending, Approved, Issued, Rejected*), and automatic inventory deduction.
3. **Purchase Order (PO) Engine**: Complete fiscal registry of purchase orders with multi-line items, automatic cost calculations, PRF tracking, and CSV export.
4. **Receiving Report (RR) Registry**: Records deliveries from suppliers, inspection conditions (*Accepted, Damaged, Defective*), delivery receipt (DR) and invoice tracking, with direct PO linkage.
5. **Material Issuance Slips (MIS)**: Official slips for construction supplies, vehicle parts, and site materials issued to drivers, engineers, and project sites with equipment plate tagging.
6. **On-Hand Inventory & Stock Master**: Master catalog of 588+ tracked items with real-time on-hand stock quantities, unit valuation, storage bins/locations, and status badges (*In Stock, Low Stock, Out of Stock*).

---

### Folder Contents
```
C:\Users\ENota\OneDrive\Desktop\Inventory and Warehouse\
├── index.html                               # Standalone web application
├── warehouseman-account.html                 # Warehouseman user-account entry point
├── supplies-dashboard.html                   # User supplies request page
├── user-profile.html                         # User account profile page
├── on_hand_inventory_data.js                # Master catalog of 588+ warehouse items & valuation
├── RII_Logo.png                             # Corporate brand logo
├── supabase_inventory_warehouse_schema.sql  # Complete PostgreSQL / Supabase DDL
└── README.md                                # System documentation & user guide
```

### Warehouseman User Account
Open `warehouseman-account.html` as the warehouseman account entry point. The account bundle includes `supplies-dashboard.html` for supplies requests and `user-profile.html` for the user profile. The original `index.html` is retained as a compatible copy of the warehouse portal.

---

### Running the System
Simply double-click or open **`index.html`** in any web browser.
* Operates offline and preserves records in `localStorage`.
* Retains compatibility with the Admin Management System.
* Includes master CSV data export on all tables.
