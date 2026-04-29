// Configurações do Supabase
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://fabengyjoxfwwszndohj.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_6r26DXJQqRit7K6sYcSXlA_jP9oxWvY',
);

// URLs de callback
const String authCallbackUrl = 'finapi://auth/callback';

// Configurações de ambiente
const bool isProduction = bool.fromEnvironment('dart.vm.product');
