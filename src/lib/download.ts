import type { Dataset } from "@/lib/datasets";

export type DownloadFormat = "csv" | "json";

export function citationIdentifier(dataset: { slug: string; version: string }) {
  return `10.62000/iyeob.${dataset.slug}.v${dataset.version}`;
}

export function citationText(dataset: Dataset) {
  return `${dataset.title}. IYEOB Synthetic Data Repository, version ${dataset.version}, ${new Date().getFullYear()}. ${dataset.license}. ${citationIdentifier(dataset)}`;
}

export function buildCitationMetadata(dataset: Dataset, extra?: Record<string, unknown>) {
  return {
    title: dataset.title,
    version: dataset.version,
    authors: dataset.authors?.length ? dataset.authors : ["IYEOB Synthetic Data Team"],
    license: dataset.license,
    generated_at: new Date().toISOString(),
    identifier: citationIdentifier(dataset),
    repository: "IYEOB Synthetic Data Repository",
    country: dataset.country,
    domain: dataset.domain,
    data_notice:
      "Fully synthetic data. No real people or organizations are represented. Not an official statistic.",
    citation: citationText(dataset),
    ...extra,
  };
}

function saveFile(name: string, content: string, type: string) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = name;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function toCsv(rows: Record<string, unknown>[], columns: string[]) {
  const escape = (value: unknown) => {
    const text = value == null ? "" : String(value);
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  };
  return [columns.join(","), ...rows.map((row) => columns.map((column) => escape(row[column])).join(","))].join("\n");
}

/**
 * Downloads the data file plus a separate citation metadata sidecar.
 * Column selection keeps the download aligned with what the user filtered to.
 */
export function downloadDatasetSample(
  dataset: Dataset,
  format: DownloadFormat,
  selectedColumns?: string[],
) {
  const allColumns = Object.keys(dataset.preview[0] ?? {});
  const columns = selectedColumns?.length ? selectedColumns.filter((c) => allColumns.includes(c)) : allColumns;
  const rows = dataset.preview.map((row) =>
    Object.fromEntries(columns.map((column) => [column, row[column]])),
  );

  const base = `${dataset.slug}-sample`;
  if (format === "json") {
    saveFile(`${base}.json`, JSON.stringify(rows, null, 2), "application/json");
  } else {
    saveFile(`${base}.csv`, toCsv(rows, columns), "text/csv");
  }

  saveFile(
    `${base}-citation.json`,
    JSON.stringify(buildCitationMetadata(dataset, { file: `${base}.${format}`, columns, row_count: rows.length }), null, 2),
    "application/json",
  );
}

/** Catalog-level export of the datasets currently matching the active filters. */
export function downloadCatalogSelection(
  datasets: Dataset[],
  format: DownloadFormat,
  filters: Record<string, string>,
) {
  const rows = datasets.map((dataset) => ({
    slug: dataset.slug,
    title: dataset.title,
    domain: dataset.domain,
    task: dataset.task,
    difficulty: dataset.difficulty,
    country: dataset.country,
    rows: dataset.rows,
    version: dataset.version,
    license: dataset.license,
    quality: dataset.quality,
    identifier: citationIdentifier(dataset),
  }));
  const columns = Object.keys(rows[0] ?? { slug: "", title: "" });

  if (format === "json") {
    saveFile("iyeob-catalog-selection.json", JSON.stringify(rows, null, 2), "application/json");
  } else {
    saveFile("iyeob-catalog-selection.csv", toCsv(rows, columns), "text/csv");
  }

  saveFile(
    "iyeob-catalog-selection-citation.json",
    JSON.stringify(
      {
        title: "IYEOB Synthetic Dataset Catalog — filtered selection",
        version: "catalog",
        authors: ["IYEOB Synthetic Data Team"],
        license: "CC BY 4.0",
        generated_at: new Date().toISOString(),
        identifier: `10.62000/iyeob.catalog.${new Date().toISOString().slice(0, 10)}`,
        applied_filters: filters,
        dataset_count: rows.length,
        included_datasets: rows.map((row) => row.identifier),
        data_notice: "Fully synthetic data. No real people or organizations are represented.",
      },
      null,
      2,
    ),
    "application/json",
  );
}
