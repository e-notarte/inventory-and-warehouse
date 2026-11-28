const fs = require('fs');
const path = require('path');
const https = require('https');
const XLSX = require('xlsx');

// Supabase Configuration from warehouseman-account.html
const SUPABASE_URL = 'https://toumsirfqtvdzdrnhncw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvdW1zaXJmcXR2ZHpkcm5obmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2NDQyMjksImV4cCI6MjEwNTIyMDIyOX0.7lcrL4AOVR4MeWJjybb-5wmzGoey3qHHfvc1_or9pG4';

function normalizeHeader(h) {
  return String(h || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_');
}

function parseExcelDate(val) {
  if (!val) return '';
  if (typeof val === 'number') {
    // Excel date serial number
    const date = new Date(Math.round((val - 25569) * 86400 * 1000));
    return date.toISOString().split('T')[0];
  }
  const s = String(val).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  
  // Try parsing date string like DD-MMM-YYYY or MM/DD/YYYY
  const parsed = Date.parse(s);
  if (!isNaN(parsed)) {
    return new Date(parsed).toISOString().split('T')[0];
  }
  return s;
}

function findBestColumn(keys, aliases) {
  for (const alias of aliases) {
    const match = keys.find(k => k === alias || k.includes(alias));
    if (match) return match;
  }
  return null;
}

function findTargetFile(argFile) {
  if (argFile && fs.existsSync(argFile)) {
    return argFile;
  }
  
  const files = fs.readdirSync('.');
  const excelFiles = files.filter(f => /\.(xlsx|xls|csv)$/i.test(f) && !f.startsWith('~$'));
  
  // Look for MIS-specific names first
  const misMatch = excelFiles.find(f => /mis|issuance|release/i.test(f));
  if (misMatch) return misMatch;
  
  return excelFiles[0] || null;
}

async function uploadToSupabase(table, records, chunkSize = 50) {
  if (!records || records.length === 0) return 0;
  let totalUploaded = 0;

  for (let i = 0; i < records.length; i += chunkSize) {
    const chunk = records.slice(i, i + chunkSize);
    const body = JSON.stringify(chunk);

    await new Promise((resolve, reject) => {
      const url = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
      const req = https.request(url, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=representation'
        }
      }, (res) => {
        let respData = '';
        res.on('data', c => respData += c);
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            totalUploaded += chunk.length;
            resolve();
          } else {
            console.warn(`[Supabase Upload Notice] Status ${res.statusCode}:`, respData.substring(0, 300));
            resolve(); // Do not block script on partial duplicate warning
          }
        });
      });
      req.on('error', (err) => {
        console.warn(`[Supabase Network Warning]:`, err.message);
        resolve();
      });
      req.write(body);
      req.end();
    });
  }
  return totalUploaded;
}

async function main() {
  console.log('========================================================');
  console.log('  MATERIAL ISSUANCE (MIS) AUTOMATED MIGRATION TOOL');
  console.log('  R-II Builders, Inc. - Warehouse Management System');
  console.log('========================================================\n');

  const targetFile = findTargetFile(process.argv[2]);
  if (!targetFile) {
    console.log('⏳ No Material Issuance spreadsheet found in current directory.');
    console.log('   Expected file: e.g. "2026 MIS.xlsx", "Material Issuance Summary.xlsx", or CSV.');
    console.log('   Please download or drop your file into this directory and re-run:');
    console.log('   node migrate_mis.js "<filename>"\n');
    process.exit(0);
  }

  console.log(`📁 Found target file: ${targetFile}`);
  console.log('📖 Reading workbook...');

  const workbook = XLSX.readFile(targetFile, { cellDates: true, raw: false });
  const sheetName = workbook.SheetNames[0];
  console.log(`📄 Using sheet: "${sheetName}"`);

  const worksheet = workbook.Sheets[sheetName];
  const rawRows = XLSX.utils.sheet_to_json(worksheet, { defval: '' });

  if (!rawRows || rawRows.length === 0) {
    console.error('❌ Error: The selected sheet contains no data rows.');
    process.exit(1);
  }

  console.log(`🔍 Total raw rows read: ${rawRows.length}`);

  // Detect and normalize columns
  const rawKeys = Object.keys(rawRows[0]);
  const normKeyMap = {};
  rawKeys.forEach(k => {
    normKeyMap[normalizeHeader(k)] = k;
  });
  const normKeys = Object.keys(normKeyMap);

  const colMisNo = normKeyMap[findBestColumn(normKeys, ['mis_no', 'mis_num', 'mis', 'issue_no', 'slip_no', 'reference', 'ref_no'])];
  const colDate = normKeyMap[findBestColumn(normKeys, ['issue_date', 'date_issued', 'date', 'mis_date', 'trans_date'])];
  const colRecipient = normKeyMap[findBestColumn(normKeys, ['recipient', 'issued_to', 'receiver', 'received_by', 'driver', 'requestor', 'name', 'personnel'])];
  const colProject = normKeyMap[findBestColumn(normKeys, ['project', 'charge_to', 'charge', 'project_charge_to', 'site', 'location', 'cost_center'])];
  const colDept = normKeyMap[findBestColumn(normKeys, ['department', 'dept', 'office', 'section', 'division'])];
  const colPurpose = normKeyMap[findBestColumn(normKeys, ['purpose', 'remarks', 'notes', 'reason', 'particulars', 'description_of_work'])];
  const colPlate = normKeyMap[findBestColumn(normKeys, ['plate', 'plate_no', 'tagged_equipment', 'equipment', 'vehicle', 'truck_no', 'equipment_plate'])];
  
  const colItemDesc = normKeyMap[findBestColumn(normKeys, ['item_description', 'description', 'item_desc', 'particulars', 'item_name', 'materials', 'items', 'item'])];
  const colItemCode = normKeyMap[findBestColumn(normKeys, ['item_code', 'code', 'stock_code', 'stock_no', 'part_no'])];
  const colQty = normKeyMap[findBestColumn(normKeys, ['qty', 'quantity', 'issued_qty', 'qty_issued', 'amount_qty'])];
  const colUom = normKeyMap[findBestColumn(normKeys, ['uom', 'unit', 'unit_of_measure'])];
  const colCost = normKeyMap[findBestColumn(normKeys, ['unit_cost', 'cost', 'price', 'unit_price', 'rate'])];
  const colTotal = normKeyMap[findBestColumn(normKeys, ['total_amount', 'total_cost', 'total_value', 'line_total', 'total', 'amount'])];

  console.log('\n--- DETECTED COLUMN MAPPINGS ---');
  console.log(`  MIS No:             ${colMisNo || '(Not found - will auto-generate)'}`);
  console.log(`  Date:               ${colDate || '(Defaulting to current date)'}`);
  console.log(`  Recipient / Driver: ${colRecipient || '(Defaulting to Personnel)'}`);
  console.log(`  Project / Charge:   ${colProject || '(Defaulting to Head Office)'}`);
  console.log(`  Department:         ${colDept || '(Defaulting to Admin)'}`);
  console.log(`  Purpose / Notes:    ${colPurpose || '(Empty)'}`);
  console.log(`  Plate / Equipment:  ${colPlate || '(Empty)'}`);
  console.log(`  Item Description:   ${colItemDesc || '(Required line item description)'}`);
  console.log(`  Item Code:          ${colItemCode || '(Optional code)'}`);
  console.log(`  Quantity:           ${colQty || '(Defaulting to 1)'}`);
  console.log(`  Unit of Measure:    ${colUom || '(Defaulting to PCS)'}`);
  console.log(`  Unit Cost (₱):      ${colCost || '(Defaulting to 0.00)'}`);
  console.log(`  Total Amount (₱):   ${colTotal || '(Auto-calculated)'}`);
  console.log('--------------------------------\n');

  // Group items by MIS Number or unique slip
  const misMap = new Map();
  let generatedCounter = 1;

  rawRows.forEach((row, rowIdx) => {
    let misNo = colMisNo ? String(row[colMisNo] || '').trim() : '';
    if (!misNo) {
      misNo = `MIS-2026-${String(generatedCounter++).padStart(4, '0')}`;
    }

    const itemDesc = colItemDesc ? String(row[colItemDesc] || '').trim() : '';
    const itemCode = colItemCode ? String(row[colItemCode] || '').trim() : '';
    const qty = colQty ? (parseFloat(row[colQty]) || 1) : 1;
    const uom = colUom ? (String(row[colUom] || '').trim().toUpperCase() || 'PCS') : 'PCS';
    const cost = colCost ? (parseFloat(row[colCost]) || 0) : 0;
    const rowTotal = colTotal ? (parseFloat(row[colTotal]) || (qty * cost)) : (qty * cost);

    const dateVal = colDate ? parseExcelDate(row[colDate]) : new Date().toISOString().split('T')[0];
    const recipient = colRecipient ? String(row[colRecipient] || '').trim() : 'Warehouse Staff';
    const project = colProject ? String(row[colProject] || '').trim() : 'Head Office';
    const dept = colDept ? String(row[colDept] || '').trim() : 'Admin';
    const purpose = colPurpose ? String(row[colPurpose] || '').trim() : '';
    const plate = colPlate ? String(row[colPlate] || '').trim() : '';

    if (!misMap.has(misNo)) {
      misMap.set(misNo, {
        id: `mis_${dateVal.replace(/-/g, '')}_${misNo.replace(/[^a-zA-Z0-9]/g, '_')}`,
        mis_no: misNo,
        date: dateVal,
        recipient_name: recipient || 'Personnel',
        project: project || 'Head Office',
        department: dept || 'Admin',
        project_dept: project ? `${project} • ${dept}` : dept,
        purpose: purpose || 'Official Material Issuance',
        tagged_plate: plate || '',
        items: [],
        total_issuance_value: 0,
        status: 'ISSUED',
        created_at: new Date().toISOString()
      });
    }

    const mis = misMap.get(misNo);
    if (itemDesc) {
      mis.items.push({
        desc: itemDesc,
        item_code: itemCode,
        qty: qty,
        uom: uom,
        cost: cost,
        rowTotal: rowTotal
      });
      mis.total_issuance_value += rowTotal;
    }
  });

  const materialIssuances = Array.from(misMap.values()).map(m => {
    if (m.items.length === 0) {
      m.items.push({
        desc: 'General Warehouse Materials',
        qty: 1,
        uom: 'LOT',
        cost: m.total_issuance_value || 0,
        rowTotal: m.total_issuance_value || 0
      });
    }
    m.items_desc = m.items.map(it => `${it.desc} (${it.qty} ${it.uom})`).join(', ');
    return m;
  });

  console.log(`✅ Grouped into ${materialIssuances.length} Material Issuance Slips.`);
  const totalValuation = materialIssuances.reduce((s, m) => s + m.total_issuance_value, 0);
  const totalItemsCount = materialIssuances.reduce((s, m) => s + m.items.length, 0);
  console.log(`📦 Total line items: ${totalItemsCount}`);
  console.log(`💰 Total Valuation: ₱ ${totalValuation.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);

  // Write to migrated_mis_data.js
  const outputJs = `// Auto-generated by migrate_mis.js on ${new Date().toISOString()}
var migratedMisData = {
  meta: {
    source_file: ${JSON.stringify(targetFile)},
    total_issuances: ${materialIssuances.length},
    total_items: ${totalItemsCount},
    total_valuation: ${totalValuation},
    generated_at: ${JSON.stringify(new Date().toISOString())}
  },
  materialIssuances: ${JSON.stringify(materialIssuances, null, 2)}
};

if (typeof window !== 'undefined') {
  window.migratedMisData = migratedMisData;
}
`;

  fs.writeFileSync('migrated_mis_data.js', outputJs, 'utf8');
  console.log('\n📄 Successfully wrote to migrated_mis_data.js');

  // Push directly to Supabase material_issuances table
  console.log('☁️  Pushing migrated issuances to Supabase "material_issuances" table...');
  const sbPayload = materialIssuances.map(m => {
    const totalQty = m.items.reduce((s, it) => s + (Number(it.qty) || 0), 0) || 1;
    return {
      id: m.id,
      mis_no: m.mis_no,
      issue_date: m.date,
      department: m.project_dept || m.department || 'Admin',
      issued_to: m.recipient_name || 'Personnel',
      purpose: m.purpose || '',
      tagged_equipment_plate: m.tagged_plate || '',
      items: m.items,
      items_desc: m.items_desc || '',
      total_qty: totalQty,
      total_amount: Number(m.total_issuance_value) || 0,
      remarks: m.tagged_plate ? `Plate/Equipment: ${m.tagged_plate}` : (m.purpose || ''),
      status: 'ISSUED'
    };
  });

  const uploadedCount = await uploadToSupabase('material_issuances', sbPayload);
  console.log(`✨ Successfully uploaded ${uploadedCount} Material Issuance records to Supabase!`);
  console.log('\n🎉 Migration complete! Open or refresh warehouseman-account.html to view.');
}

main().catch(err => {
  console.error('❌ Migration failed with error:', err);
});
