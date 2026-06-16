const supabase = require('../config/supabase');
const logger = require('../config/logger');
const { successResponse, errorResponse } = require('../utils/response');
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');

// ── Helper: ambil data laporan ───────────────────────────────────────────────
const _fetchReportData = async (bulan, tahun, idDepartemen, tenantId) => {
  const startDate = `${tahun}-${String(bulan).padStart(2, '0')}-01`;
  const endDate   = bulan < 12
    ? `${tahun}-${String(bulan + 1).padStart(2, '0')}-01`
    : `${tahun + 1}-01-01`;

  let profileQuery = supabase
    .from('profiles')
    .select('id, nama, email, id_departemen')
    .eq('status_aktif', true)
    .eq('role', 'karyawan')
    .eq('id_tenant', tenantId);

  if (idDepartemen) profileQuery = profileQuery.eq('id_departemen', idDepartemen);

  const { data: employees, error: empErr } = await profileQuery;
  if (empErr) throw empErr;
  if (!employees?.length) return { employees: [], absensiByKaryawan: {}, startDate, endDate, bulan, tahun };

  const ids = employees.map((e) => e.id);
  const { data: absensiList, error: absensiErr } = await supabase
    .from('absensi')
    .select('id_karyawan, status, menit_terlambat')
    .in('id_karyawan', ids)
    .eq('id_tenant', tenantId)
    .gte('tanggal', startDate)
    .lt('tanggal', endDate);

  if (absensiErr) throw absensiErr;

  const absensiByKaryawan = {};
  for (const a of absensiList || []) {
    if (!absensiByKaryawan[a.id_karyawan]) absensiByKaryawan[a.id_karyawan] = [];
    absensiByKaryawan[a.id_karyawan].push(a);
  }

  return { employees, absensiByKaryawan, startDate, endDate, bulan, tahun };
};

const _buildDetails = (employees, absensiByKaryawan) => employees.map((emp) => {
  const records = absensiByKaryawan[emp.id] || [];
  const hadir     = records.filter((r) => r.status === 'hadir').length;
  const terlambat = records.filter((r) => r.status === 'terlambat').length;
  const izin      = records.filter((r) => r.status === 'izin').length;
  const alpha     = records.filter((r) => r.status === 'alpha').length;
  const totalMenitTerlambat = records.reduce((s, r) => s + (r.menit_terlambat || 0), 0);
  return { id: emp.id, nama: emp.nama, email: emp.email, hadir, terlambat, izin, alpha, total_menit_terlambat: totalMenitTerlambat };
});

const BULAN_NAMES = ['', 'Januari','Februari','Maret','April','Mei','Juni',
  'Juli','Agustus','September','Oktober','November','Desember'];

// ── Laporan bulanan ──────────────────────────────────────────────────────────
const getMonthlyReport = async (req, res) => {
  const bulan         = parseInt(req.query.bulan)  || new Date().getMonth() + 1;
  const tahun         = parseInt(req.query.tahun)  || new Date().getFullYear();
  const id_departemen = req.query.id_departemen    || null;

  try {
    const { employees, absensiByKaryawan } = await _fetchReportData(bulan, tahun, id_departemen, req.tenantId);

    if (!employees.length) {
      return successResponse(res, 'Laporan bulanan', {
        summary: { total_karyawan: 0, total_hadir: 0, total_terlambat: 0, total_izin: 0, total_alpha: 0 },
        details: [],
      });
    }

    const details = _buildDetails(employees, absensiByKaryawan);
    const summary = {
      total_karyawan:  details.length,
      total_hadir:     details.reduce((s, d) => s + d.hadir + d.terlambat, 0),
      total_terlambat: details.reduce((s, d) => s + d.terlambat, 0),
      total_izin:      details.reduce((s, d) => s + d.izin, 0),
      total_alpha:     details.reduce((s, d) => s + d.alpha, 0),
    };

    return successResponse(res, 'Laporan bulanan berhasil diambil', { summary, details });
  } catch (err) {
    logger.error('[getMonthlyReport]', err);
    return errorResponse(res, 'Gagal mengambil laporan bulanan');
  }
};

// ── Export Excel ─────────────────────────────────────────────────────────────
const exportExcel = async (req, res) => {
  const bulan         = parseInt(req.query.bulan)  || new Date().getMonth() + 1;
  const tahun         = parseInt(req.query.tahun)  || new Date().getFullYear();
  const id_departemen = req.query.id_departemen    || null;

  try {
    const { employees, absensiByKaryawan } = await _fetchReportData(bulan, tahun, id_departemen, req.tenantId);
    const details = _buildDetails(employees, absensiByKaryawan);

    const wb = new ExcelJS.Workbook();
    wb.creator = 'SiAbsen';
    wb.created  = new Date();

    const ws = wb.addWorksheet(`Laporan ${BULAN_NAMES[bulan]} ${tahun}`);

    // ── Header judul ─────────────────────────────────────────────────────────
    ws.mergeCells('A1:G1');
    ws.getCell('A1').value = `LAPORAN ABSENSI KARYAWAN — ${BULAN_NAMES[bulan].toUpperCase()} ${tahun}`;
    ws.getCell('A1').font  = { bold: true, size: 14 };
    ws.getCell('A1').alignment = { horizontal: 'center' };

    ws.mergeCells('A2:G2');
    ws.getCell('A2').value = `Dicetak: ${new Date().toLocaleDateString('id-ID', { dateStyle: 'full' })}`;
    ws.getCell('A2').font  = { italic: true, size: 10 };
    ws.getCell('A2').alignment = { horizontal: 'center' };

    ws.addRow([]);

    // ── Header kolom ─────────────────────────────────────────────────────────
    const headerRow = ws.addRow(['No', 'Nama', 'Email', 'Hadir', 'Terlambat', 'Izin', 'Alpha']);
    headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E3A8A' } };
    headerRow.alignment = { horizontal: 'center' };
    headerRow.height = 22;

    // Lebar kolom
    ws.getColumn(1).width = 5;
    ws.getColumn(2).width = 28;
    ws.getColumn(3).width = 32;
    ws.getColumn(4).width = 10;
    ws.getColumn(5).width = 12;
    ws.getColumn(6).width = 10;
    ws.getColumn(7).width = 10;

    // ── Data rows ─────────────────────────────────────────────────────────────
    details.forEach((d, idx) => {
      const row = ws.addRow([idx + 1, d.nama, d.email, d.hadir, d.terlambat, d.izin, d.alpha]);
      row.alignment = { horizontal: 'center' };
      // Highlight alpha > 0 dengan merah muda
      if (d.alpha > 0) {
        row.getCell(7).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEE2E2' } };
        row.getCell(7).font = { color: { argb: 'FFDC2626' }, bold: true };
      }
      // Highlight terlambat > 3 dengan oranye muda
      if (d.terlambat > 3) {
        row.getCell(5).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFF7ED' } };
        row.getCell(5).font = { color: { argb: 'FFD97706' }, bold: true };
      }
      // Warnai nama kiri
      row.getCell(2).alignment = { horizontal: 'left' };
      row.getCell(3).alignment = { horizontal: 'left' };
    });

    // ── Summary row ───────────────────────────────────────────────────────────
    ws.addRow([]);
    const totalRow = ws.addRow([
      '', 'TOTAL', '',
      details.reduce((s, d) => s + d.hadir, 0),
      details.reduce((s, d) => s + d.terlambat, 0),
      details.reduce((s, d) => s + d.izin, 0),
      details.reduce((s, d) => s + d.alpha, 0),
    ]);
    totalRow.font = { bold: true };
    totalRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEFF6FF' } };

    // ── Border semua sel data ─────────────────────────────────────────────────
    const lastRow = ws.lastRow.number;
    for (let r = 4; r <= lastRow; r++) {
      for (let c = 1; c <= 7; c++) {
        ws.getCell(r, c).border = {
          top:    { style: 'thin', color: { argb: 'FFE2E8F0' } },
          left:   { style: 'thin', color: { argb: 'FFE2E8F0' } },
          bottom: { style: 'thin', color: { argb: 'FFE2E8F0' } },
          right:  { style: 'thin', color: { argb: 'FFE2E8F0' } },
        };
      }
    }

    // ── Kirim response ────────────────────────────────────────────────────────
    const filename = `laporan_absensi_${BULAN_NAMES[bulan]}_${tahun}.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    await wb.xlsx.write(res);
    res.end();
  } catch (err) {
    logger.error('[exportExcel]', err);
    return errorResponse(res, 'Gagal export Excel');
  }
};

// ── Export PDF ────────────────────────────────────────────────────────────────
const exportPdf = async (req, res) => {
  const bulan         = parseInt(req.query.bulan)  || new Date().getMonth() + 1;
  const tahun         = parseInt(req.query.tahun)  || new Date().getFullYear();
  const id_departemen = req.query.id_departemen    || null;

  try {
    const { employees, absensiByKaryawan } = await _fetchReportData(bulan, tahun, id_departemen, req.tenantId);
    const details = _buildDetails(employees, absensiByKaryawan);
    const summary = {
      total_karyawan:  details.length,
      total_hadir:     details.reduce((s, d) => s + d.hadir + d.terlambat, 0),
      total_terlambat: details.reduce((s, d) => s + d.terlambat, 0),
      total_izin:      details.reduce((s, d) => s + d.izin, 0),
      total_alpha:     details.reduce((s, d) => s + d.alpha, 0),
    };

    const filename = `laporan_absensi_${BULAN_NAMES[bulan]}_${tahun}.pdf`;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    doc.pipe(res);

    // ── Judul ─────────────────────────────────────────────────────────────────
    doc.fontSize(18).font('Helvetica-Bold')
       .text('LAPORAN ABSENSI KARYAWAN', { align: 'center' });
    doc.fontSize(13).font('Helvetica')
       .text(`${BULAN_NAMES[bulan]} ${tahun}`, { align: 'center' });
    doc.moveDown(0.3);
    doc.fontSize(9).fillColor('#64748B')
       .text(`Dicetak: ${new Date().toLocaleDateString('id-ID', { dateStyle: 'full' })}`, { align: 'center' });
    doc.moveDown(1);

    // ── Summary cards ─────────────────────────────────────────────────────────
    const cardY   = doc.y;
    const cardW   = 100;
    const cardGap = 12;
    const cards   = [
      { label: 'Total Karyawan', value: summary.total_karyawan, color: '#2563EB' },
      { label: 'Hadir',          value: summary.total_hadir,     color: '#16A34A' },
      { label: 'Terlambat',      value: summary.total_terlambat, color: '#D97706' },
      { label: 'Izin',           value: summary.total_izin,      color: '#0891B2' },
      { label: 'Alpha',          value: summary.total_alpha,     color: '#DC2626' },
    ];

    cards.forEach((card, i) => {
      const x = 40 + i * (cardW + cardGap);
      doc.roundedRect(x, cardY, cardW, 52, 6).fillAndStroke('#F8FAFC', '#E2E8F0');
      doc.fillColor(card.color).fontSize(20).font('Helvetica-Bold')
         .text(String(card.value), x, cardY + 8, { width: cardW, align: 'center' });
      doc.fillColor('#64748B').fontSize(8).font('Helvetica')
         .text(card.label, x, cardY + 34, { width: cardW, align: 'center' });
    });

    doc.moveDown(4.5);

    // ── Tabel ─────────────────────────────────────────────────────────────────
    const tableTop = doc.y + 5;
    const colWidths = [25, 155, 165, 40, 55, 40, 40];
    const colX      = colWidths.reduce((acc, w, i) => {
      acc.push(i === 0 ? 40 : acc[i - 1] + colWidths[i - 1]);
      return acc;
    }, []);
    const rowH = 22;

    // Header tabel
    doc.rect(40, tableTop, 520, rowH).fill('#1E3A8A');
    const headers = ['No', 'Nama', 'Email', 'H', 'Terlambat', 'I', 'A'];
    headers.forEach((h, i) => {
      doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica-Bold')
         .text(h, colX[i], tableTop + 7, { width: colWidths[i], align: 'center' });
    });

    // Data rows
    details.forEach((d, idx) => {
      const y   = tableTop + rowH * (idx + 1);
      const bg  = idx % 2 === 0 ? '#FFFFFF' : '#F8FAFC';
      doc.rect(40, y, 520, rowH).fill(bg);

      const cells = [idx + 1, d.nama, d.email, d.hadir, d.terlambat, d.izin, d.alpha];
      cells.forEach((val, ci) => {
        let color = '#0F172A';
        if (ci === 6 && d.alpha > 0)     color = '#DC2626';
        if (ci === 4 && d.terlambat > 3) color = '#D97706';
        doc.fillColor(color).fontSize(8).font(ci === 4 && d.terlambat > 3 ? 'Helvetica-Bold' : 'Helvetica')
           .text(String(val), colX[ci], y + 7, {
             width: colWidths[ci],
             align: ci >= 3 ? 'center' : 'left',
             ellipsis: true,
           });
      });

      // Garis pembatas
      doc.moveTo(40, y + rowH).lineTo(560, y + rowH).strokeColor('#E2E8F0').lineWidth(0.5).stroke();
    });

    // Border luar tabel
    const tableH = rowH * (details.length + 1);
    doc.rect(40, tableTop, 520, tableH).strokeColor('#CBD5E1').lineWidth(1).stroke();

    doc.end();
  } catch (err) {
    logger.error('[exportPdf]', err);
    if (!res.headersSent) return errorResponse(res, 'Gagal export PDF');
    res.end();
  }
};

module.exports = { getMonthlyReport, exportExcel, exportPdf };
