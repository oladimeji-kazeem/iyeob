export type DatasetColumn = {
  name: string;
  type: string;
  description: string;
  example: string;
  role: "Feature" | "Target" | "Identifier";
};

export type Dataset = {
  slug: string;
  title: string;
  shortTitle: string;
  domain: string;
  task: string;
  difficulty: "Beginner" | "Intermediate" | "Advanced";
  country: string;
  rows: number;
  size: string;
  version: string;
  quality: number;
  completeness: number;
  privacy: number;
  fidelity: number;
  description: string;
  intendedUse: string;
  methodology: string;
  assumptions: string[];
  limitations: string[];
  researchQuestions: string[];
  license: string;
  authors?: string[];
  columns: DatasetColumn[];
  preview: Record<string, string | number>[];
};

export const datasets: Dataset[] = [
  {
    slug: "nigerian-sme-loan-default",
    title: "Nigerian SME Loan Default",
    shortTitle: "SME Loan Default",
    domain: "Financial Services",
    task: "Classification",
    difficulty: "Intermediate",
    country: "Nigeria",
    rows: 10000,
    size: "2.8 MB",
    version: "1.2.0",
    quality: 96,
    completeness: 99,
    privacy: 100,
    fidelity: 93,
    description: "A research-ready synthetic credit-risk dataset modelling small business loan applications across Nigeria’s six geopolitical zones.",
    intendedUse: "Credit-risk model prototyping, fairness analysis, feature engineering practice, and classroom research.",
    methodology: "Generated from a constrained probabilistic model. Business revenue, operating age, requested amount, repayment burden, and prior arrears jointly influence default risk. State and sector affect distributions without reproducing any real person or company.",
    assumptions: ["Higher repayment burden increases default likelihood.", "Longer operating history generally reduces risk.", "Seasonal sectors show more variable monthly revenue."],
    limitations: ["Not a measure of Nigeria’s real default rate.", "Cannot support lending decisions about real people or businesses.", "Geographic patterns are designed scenarios, not observations."],
    researchQuestions: ["How does repayment burden affect predicted default?", "Which features remain robust across geopolitical zones?", "How does class balancing change calibration?"],
    license: "CC BY 4.0",
    columns: [
      { name: "business_id", type: "string", description: "Synthetic record identifier", example: "SME-10482", role: "Identifier" },
      { name: "state", type: "category", description: "Nigerian state of operation", example: "Kaduna", role: "Feature" },
      { name: "sector", type: "category", description: "Primary business sector", example: "Wholesale", role: "Feature" },
      { name: "monthly_revenue_ngn", type: "integer", description: "Modelled monthly business revenue", example: "1850000", role: "Feature" },
      { name: "loan_amount_ngn", type: "integer", description: "Requested principal amount", example: "950000", role: "Feature" },
      { name: "repayment_burden", type: "float", description: "Monthly repayment as share of revenue", example: "0.24", role: "Feature" },
      { name: "defaulted", type: "boolean", description: "Synthetic target outcome", example: "false", role: "Target" },
    ],
    preview: [
      { business_id: "SME-10482", state: "Kaduna", sector: "Wholesale", monthly_revenue_ngn: 1850000, loan_amount_ngn: 950000, repayment_burden: 0.24, defaulted: "false" },
      { business_id: "SME-20711", state: "Lagos", sector: "Logistics", monthly_revenue_ngn: 3200000, loan_amount_ngn: 2500000, repayment_burden: 0.31, defaulted: "false" },
      { business_id: "SME-38104", state: "Abia", sector: "Retail", monthly_revenue_ngn: 640000, loan_amount_ngn: 800000, repayment_burden: 0.47, defaulted: "true" },
    ],
  },
  {
    slug: "nigerian-telecom-customer-churn",
    title: "Nigerian Telecom Customer Churn",
    shortTitle: "Telecom Customer Churn",
    domain: "Telecommunications",
    task: "Classification",
    difficulty: "Intermediate",
    country: "Nigeria",
    rows: 25000,
    size: "5.1 MB",
    version: "1.1.0",
    quality: 94,
    completeness: 98,
    privacy: 100,
    fidelity: 90,
    description: "Synthetic mobile subscriber behaviour with prepaid and postpaid tiers, usage, network experience, support interactions, and churn outcomes.",
    intendedUse: "Churn prediction, retention segmentation, explainability research, and imbalanced classification practice.",
    methodology: "A conditional generator links tenure, recharge regularity, data usage, dropped-call experience, complaints, and plan tier to a synthetic churn outcome.",
    assumptions: ["Repeated unresolved complaints increase churn likelihood.", "Longer tenure reduces churn probability.", "Irregular recharge behaviour can signal disengagement."],
    limitations: ["Network tiers are fictional and not operator benchmarks.", "No real subscriber traces or locations are included."],
    researchQuestions: ["Which service signals best predict churn?", "Does tenure moderate the effect of complaints?", "How should rare churn cases be evaluated?"],
    license: "CC BY 4.0",
    columns: [
      { name: "subscriber_id", type: "string", description: "Synthetic subscriber identifier", example: "TEL-83019", role: "Identifier" },
      { name: "network_tier", type: "category", description: "Fictional service tier", example: "Plus 5G", role: "Feature" },
      { name: "tenure_months", type: "integer", description: "Months since simulated activation", example: "28", role: "Feature" },
      { name: "monthly_data_gb", type: "float", description: "Modelled monthly data use", example: "18.4", role: "Feature" },
      { name: "complaints_90d", type: "integer", description: "Support complaints in 90 days", example: "2", role: "Feature" },
      { name: "churned", type: "boolean", description: "Synthetic churn target", example: "false", role: "Target" },
    ],
    preview: [
      { subscriber_id: "TEL-83019", network_tier: "Plus 5G", tenure_months: 28, monthly_data_gb: 18.4, complaints_90d: 2, churned: "false" },
      { subscriber_id: "TEL-12840", network_tier: "Flex 4G", tenure_months: 4, monthly_data_gb: 6.2, complaints_90d: 5, churned: "true" },
      { subscriber_id: "TEL-77105", network_tier: "Value 4G", tenure_months: 51, monthly_data_gb: 9.8, complaints_90d: 0, churned: "false" },
    ],
  },
  {
    slug: "nigerian-student-performance",
    title: "Nigerian Student Performance",
    shortTitle: "Student Performance",
    domain: "Education",
    task: "Regression",
    difficulty: "Beginner",
    country: "Nigeria",
    rows: 15000,
    size: "3.4 MB",
    version: "1.0.0",
    quality: 92,
    completeness: 97,
    privacy: 100,
    fidelity: 88,
    description: "Synthetic secondary-school learning records connecting attendance, study access, assessment history, and final performance.",
    intendedUse: "Regression tutorials, educational analytics demonstrations, and responsible model evaluation.",
    methodology: "Rule-constrained simulation with non-linear relationships between attendance, study time, learning resources, prior assessment scores, and final score.",
    assumptions: ["Prior performance is predictive but not deterministic.", "Resource access has diminishing returns."],
    limitations: ["Not suitable for ranking real schools or regions.", "Does not represent national education statistics."],
    researchQuestions: ["Which factors explain score variance?", "How do missing features affect performance?"],
    license: "CC BY 4.0",
    columns: [
      { name: "learner_id", type: "string", description: "Synthetic learner identifier", example: "LRN-5502", role: "Identifier" },
      { name: "attendance_rate", type: "float", description: "Simulated attendance proportion", example: "0.91", role: "Feature" },
      { name: "study_hours_weekly", type: "float", description: "Modelled weekly study time", example: "8.5", role: "Feature" },
      { name: "resource_access", type: "category", description: "Learning resource access tier", example: "Moderate", role: "Feature" },
      { name: "final_score", type: "float", description: "Synthetic final assessment score", example: "74.2", role: "Target" },
    ],
    preview: [{ learner_id: "LRN-5502", attendance_rate: 0.91, study_hours_weekly: 8.5, resource_access: "Moderate", final_score: 74.2 }],
  },
  {
    slug: "nigerian-insurance-claims",
    title: "Nigerian Insurance Claims",
    shortTitle: "Insurance Claims",
    domain: "Insurance",
    task: "Classification / Regression",
    difficulty: "Advanced",
    country: "Nigeria",
    rows: 18000,
    size: "4.2 MB",
    version: "1.0.0",
    quality: 93,
    completeness: 98,
    privacy: 100,
    fidelity: 89,
    description: "Synthetic motor policy and claims scenarios for severity modelling and anomalous claim classification.",
    intendedUse: "Claims severity modelling, anomaly detection, and insurance analytics education.",
    methodology: "A two-stage simulator generates claim occurrence then severity from policy, vehicle, incident, and reporting attributes.",
    assumptions: ["Severity depends on incident type and vehicle value.", "Late reporting modestly raises anomaly probability."],
    limitations: ["Premium and claim values are fictional.", "Not calibrated to any insurer’s portfolio."],
    researchQuestions: ["Can one model frequency and severity jointly?", "Which features identify unusual claims?"],
    license: "CC BY 4.0",
    columns: [
      { name: "claim_id", type: "string", description: "Synthetic claim identifier", example: "CLM-42031", role: "Identifier" },
      { name: "policy_type", type: "category", description: "Policy coverage class", example: "Comprehensive", role: "Feature" },
      { name: "vehicle_value_ngn", type: "integer", description: "Modelled insured vehicle value", example: "7200000", role: "Feature" },
      { name: "claim_amount_ngn", type: "integer", description: "Synthetic claim severity", example: "480000", role: "Target" },
      { name: "anomaly_flag", type: "boolean", description: "Synthetic anomaly target", example: "false", role: "Target" },
    ],
    preview: [{ claim_id: "CLM-42031", policy_type: "Comprehensive", vehicle_value_ngn: 7200000, claim_amount_ngn: 480000, anomaly_flag: "false" }],
  },
  {
    slug: "nigerian-crop-yield",
    title: "Nigerian Crop Yield",
    shortTitle: "Crop Yield",
    domain: "Agriculture",
    task: "Regression",
    difficulty: "Intermediate",
    country: "Nigeria",
    rows: 12000,
    size: "2.6 MB",
    version: "1.0.0",
    quality: 91,
    completeness: 96,
    privacy: 100,
    fidelity: 87,
    description: "Synthetic farm-season observations linking crop type, soil profile, rainfall scenario, inputs, and modelled yield.",
    intendedUse: "Agricultural regression, scenario analysis, and geospatial feature engineering practice.",
    methodology: "Agronomic constraints shape plausible relationships among rainfall, soil class, input intensity, plot size, crop type, and yield.",
    assumptions: ["Each crop has a rainfall response range.", "Input intensity has diminishing returns."],
    limitations: ["Weather and yield values are simulated.", "Not suitable for farm planning or policy forecasts."],
    researchQuestions: ["How do rainfall scenarios interact with crop type?", "Can yield be modelled with monotonic constraints?"],
    license: "CC BY 4.0",
    columns: [
      { name: "plot_id", type: "string", description: "Synthetic plot identifier", example: "PLT-9024", role: "Identifier" },
      { name: "state", type: "category", description: "Scenario state", example: "Kano", role: "Feature" },
      { name: "crop", type: "category", description: "Cultivated crop", example: "Maize", role: "Feature" },
      { name: "rainfall_mm", type: "float", description: "Synthetic seasonal rainfall", example: "812.5", role: "Feature" },
      { name: "yield_tonnes_ha", type: "float", description: "Modelled yield per hectare", example: "3.7", role: "Target" },
    ],
    preview: [{ plot_id: "PLT-9024", state: "Kano", crop: "Maize", rainfall_mm: 812.5, yield_tonnes_ha: 3.7 }],
  },
];

export const datasetBySlug = (slug: string) => datasets.find((dataset) => dataset.slug === slug);