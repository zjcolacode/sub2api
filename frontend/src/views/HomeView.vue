<template>
  <!-- Custom Home Content: Full Page Mode -->
  <div v-if="homeContent" class="min-h-screen">
    <!-- iframe mode -->
    <iframe
      v-if="isHomeContentUrl"
      :src="homeContent.trim()"
      class="h-screen w-full border-0"
      allowfullscreen
    ></iframe>
    <!-- HTML mode - SECURITY: homeContent is admin-only setting, XSS risk is acceptable -->
    <div v-else v-html="homeContent"></div>
  </div>

  <!-- Default Home Page (commercial landing) -->
  <div
    v-else
    class="relative flex min-h-screen flex-col overflow-hidden bg-gradient-to-br from-gray-50 via-primary-50/30 to-gray-100 dark:from-dark-950 dark:via-dark-900 dark:to-dark-950"
  >
    <!-- Background Decorations -->
    <div class="pointer-events-none absolute inset-0 overflow-hidden">
      <div class="absolute -right-40 -top-40 h-96 w-96 rounded-full bg-primary-400/20 blur-3xl"></div>
      <div class="absolute -bottom-40 -left-40 h-96 w-96 rounded-full bg-primary-500/15 blur-3xl"></div>
      <div class="absolute left-1/3 top-1/4 h-72 w-72 rounded-full bg-primary-300/10 blur-3xl"></div>
      <div
        class="absolute inset-0 bg-[linear-gradient(rgba(20,184,166,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(20,184,166,0.03)_1px,transparent_1px)] bg-[size:64px_64px]"
      ></div>
    </div>

    <!-- Header -->
    <header class="relative z-20 px-6 py-4">
      <nav class="mx-auto flex max-w-6xl items-center justify-between">
        <!-- Logo -->
        <div class="flex items-center gap-2.5">
          <div class="h-10 w-10 overflow-hidden rounded-xl shadow-md">
            <img :src="siteLogo || '/logo.png'" alt="Logo" class="h-full w-full object-contain" />
          </div>
          <span class="text-lg font-bold text-gray-900 dark:text-white">{{ siteName }}</span>
        </div>

        <!-- Nav Actions -->
        <div class="flex items-center gap-3">
          <LocaleSwitcher />

          <a
            v-if="docUrl"
            :href="docUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="rounded-lg p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700 dark:text-dark-400 dark:hover:bg-dark-800 dark:hover:text-white"
            :title="t('home.viewDocs')"
          >
            <Icon name="book" size="md" />
          </a>

          <button
            @click="toggleTheme"
            class="rounded-lg p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700 dark:text-dark-400 dark:hover:bg-dark-800 dark:hover:text-white"
            :title="isDark ? t('home.switchToLight') : t('home.switchToDark')"
          >
            <Icon v-if="isDark" name="sun" size="md" />
            <Icon v-else name="moon" size="md" />
          </button>

          <router-link
            v-if="isAuthenticated"
            :to="dashboardPath"
            class="inline-flex items-center gap-1.5 rounded-full bg-gray-900 py-1 pl-1 pr-2.5 transition-colors hover:bg-gray-800 dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            <span
              class="flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-primary-400 to-primary-600 text-[10px] font-semibold text-white"
            >
              {{ userInitial }}
            </span>
            <span class="text-xs font-medium text-white">{{ t('home.dashboard') }}</span>
          </router-link>
          <router-link
            v-else
            to="/login"
            class="inline-flex items-center rounded-full bg-gray-900 px-3 py-1 text-xs font-medium text-white transition-colors hover:bg-gray-800 dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            {{ t('home.login') }}
          </router-link>
        </div>
      </nav>
    </header>

    <!-- Main Content (styled after cda2api-home) -->
    <main class="relative z-10 flex-1">
      <div class="cda-home">
        <!-- Promo Banner -->
        <div v-if="showPromo" class="cda-promo">
          <div class="cda-promo-inner">
            <span class="cda-promo-tag">{{ t('home.promo.tag') }}</span>
            <span v-if="promoTextCustom" class="cda-promo-text">{{ promoTextCustom }}</span>
            <span v-else class="cda-promo-text">
              {{ t('home.promo.before') }}
              <strong>{{ t('home.promo.highlight') }}</strong>
              {{ t('home.promo.after', { name: siteName }) }}
            </span>
            <router-link :to="registerTo" class="cda-promo-cta"
              >{{ t('home.promo.cta') }} →</router-link
            >
          </div>
        </div>

        <!-- Hero -->
        <div class="cda-hero">
          <div class="cda-hero-badge">🚀 {{ siteName }} · {{ t('home.hero.badge') }}</div>
          <h1>
            {{ t('home.hero.titlePrefix') }}<span>{{ t('home.hero.titleHighlight') }}</span>
          </h1>
          <p>{{ t('home.hero.desc') }}</p>
          <div class="cda-btn-group">
            <router-link :to="registerTo" class="cda-btn cda-btn-primary">{{
              t('home.hero.register')
            }}</router-link>
            <router-link :to="loginTo" class="cda-btn cda-btn-secondary">{{
              t('home.hero.loginConsole')
            }}</router-link>
          </div>
        </div>

        <!-- Stats -->
        <div class="cda-stats">
          <div v-for="s in stats" :key="s" class="cda-stat-card">
            <div class="cda-stat-value">{{ t(`home.stats.${s}.value`) }}</div>
            <div class="cda-stat-label">{{ t(`home.stats.${s}.label`) }}</div>
          </div>
        </div>

        <!-- Security -->
        <div class="cda-section">
          <h2 class="cda-section-title">{{ t('home.security.title') }}</h2>
          <p class="cda-section-desc">{{ t('home.security.subtitle') }}</p>
          <div class="cda-features">
            <div v-for="item in securityItems" :key="item.key" class="cda-feature-card">
              <div class="cda-feature-icon" :style="{ background: item.bg }">{{ item.icon }}</div>
              <h3>{{ t(`home.security.items.${item.key}.title`) }}</h3>
              <p>{{ t(`home.security.items.${item.key}.desc`) }}</p>
            </div>
          </div>
        </div>

        <!-- Transparent Recharge / Route Pricing -->
        <div class="cda-section">
          <div class="cda-recharge-header">
            <h2 class="cda-recharge-title">{{ t('home.models.title') }}</h2>
            <p class="cda-recharge-lead">{{ t('home.models.subtitle') }}</p>
          </div>

          <!-- Limited-time banner -->
          <div class="cda-recharge-banner">
            <div class="cda-recharge-banner-main">
              <span class="cda-recharge-banner-tag">{{ t('home.models.banner.tag') }}</span>
              <div class="cda-recharge-banner-title">{{ t('home.models.banner.title') }}</div>
            </div>
            <p class="cda-recharge-banner-desc">{{ t('home.models.banner.desc') }}</p>
          </div>

          <!-- Plan cards -->
          <div class="cda-recharge-cards">
            <div v-for="plan in rechargePlans" :key="plan.key" class="cda-recharge-card">
              <div class="cda-recharge-card-head">
                <span class="cda-recharge-badge">{{ t(`home.models.plans.${plan.key}.badge`) }}</span>
                <span class="cda-recharge-name">{{ t(`home.models.plans.${plan.key}.name`) }}</span>
              </div>
              <div class="cda-recharge-ratio">
                <span class="cda-recharge-ratio-label">{{ t('home.models.ratioLabel') }}</span>
                <span class="cda-recharge-ratio-value">{{
                  t(`home.models.plans.${plan.key}.ratio`)
                }}</span>
              </div>
              <p class="cda-recharge-desc">{{ t(`home.models.plans.${plan.key}.desc`) }}</p>
              <div class="cda-recharge-models-label">{{ t('home.models.supportedModels') }}</div>
              <div class="cda-recharge-chips">
                <span v-for="m in plan.models" :key="m" class="cda-recharge-chip">{{ m }}</span>
                <span class="cda-recharge-chip">{{ t(`home.models.plans.${plan.key}.cli`) }}</span>
              </div>
              <router-link :to="registerTo" class="cda-recharge-btn">
                ⚡ {{ t('home.models.recharge') }}
              </router-link>
            </div>
          </div>
        </div>

        <!-- Steps -->
        <div class="cda-section">
          <h2 class="cda-section-title">{{ t('home.steps.title') }}</h2>
          <p class="cda-section-desc">{{ t('home.steps.subtitle') }}</p>
          <div class="cda-steps">
            <div v-for="(step, index) in steps" :key="step" class="cda-step">
              <div class="cda-step-num">{{ index + 1 }}</div>
              <h3>{{ t(`home.steps.items.${step}.title`) }}</h3>
              <p>{{ t(`home.steps.items.${step}.desc`) }}</p>
            </div>
          </div>
        </div>

        <!-- FAQ -->
        <div class="cda-section">
          <h2 class="cda-section-title">{{ t('home.faq.title') }}</h2>
          <p class="cda-section-desc">{{ t('home.faq.subtitle') }}</p>
          <div class="cda-faq-list">
            <div v-for="item in faqItems" :key="item" class="cda-faq-item">
              <h4>{{ t(`home.faq.items.${item}.q`) }}</h4>
              <p>{{ t(`home.faq.items.${item}.a`) }}</p>
            </div>
          </div>
        </div>

        <!-- CTA -->
        <div class="cda-cta">
          <h2>{{ t('home.cta.title', { name: siteName }) }}</h2>
          <p>{{ t('home.cta.subtitle') }}</p>
          <div class="cda-btn-group">
            <router-link :to="registerTo" class="cda-btn cda-btn-primary">{{
              t('home.cta.register')
            }}</router-link>
            <router-link :to="loginTo" class="cda-btn cda-btn-secondary">{{
              t('home.cta.login')
            }}</router-link>
          </div>
        </div>

        <!-- Disclaimer -->
        <div class="cda-disclaimer">
          <div class="cda-disclaimer-inner">
            <div class="cda-disclaimer-header">
              <div class="cda-disclaimer-icon">⚖️</div>
              <div class="cda-disclaimer-title">{{ t('home.disclaimer.title') }}</div>
            </div>
            <div class="cda-disclaimer-body">
              <p>
                {{ t('home.disclaimer.p1a')
                }}<span class="cda-disclaimer-highlight">{{ t('home.disclaimer.location') }}</span
                >{{ t('home.disclaimer.p1b')
                }}<span class="cda-disclaimer-highlight">{{ t('home.disclaimer.crossBorder') }}</span
                >{{ t('home.disclaimer.p1c') }}
              </p>
              <ul>
                <li v-for="item in disclaimerItems" :key="item">
                  {{ t(`home.disclaimer.items.${item}`) }}
                </li>
              </ul>
              <div class="cda-disclaimer-divider"></div>
              <p>{{ t('home.disclaimer.p2') }}</p>
            </div>
            <div class="cda-disclaimer-footer">
              © {{ siteName }} · {{ t('home.disclaimer.copyright') }}
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Footer -->
    <footer class="relative z-10 border-t border-gray-200/50 px-6 py-8 dark:border-dark-800/50">
      <div
        class="mx-auto flex max-w-6xl flex-col items-center justify-center gap-4 text-center sm:flex-row sm:text-left"
      >
        <p class="text-sm text-gray-500 dark:text-dark-400">
          &copy; {{ currentYear }} {{ siteName }}. {{ t('home.footer.allRightsReserved') }}
        </p>
        <div class="flex items-center gap-4">
          <a
            v-if="docUrl"
            :href="docUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="text-sm text-gray-500 transition-colors hover:text-gray-700 dark:text-dark-400 dark:hover:text-white"
          >
            {{ t('home.docs') }}
          </a>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuthStore, useAppStore } from '@/stores'
import LocaleSwitcher from '@/components/common/LocaleSwitcher.vue'
import Icon from '@/components/icons/Icon.vue'

const { t } = useI18n()

const authStore = useAuthStore()
const appStore = useAppStore()

// Site settings - directly from appStore (already initialized from injected config)
const siteName = computed(() => appStore.cachedPublicSettings?.site_name || appStore.siteName || 'Sub2API')
const siteLogo = computed(() => appStore.cachedPublicSettings?.site_logo || appStore.siteLogo || '')
const docUrl = computed(() => appStore.cachedPublicSettings?.doc_url || appStore.docUrl || '')
const homeContent = computed(() => appStore.cachedPublicSettings?.home_content || '')

// Promo banner (admin-configurable via public settings; defaults to shown)
const showPromo = computed(() => appStore.cachedPublicSettings?.home_promo_enabled !== false)
const promoTextCustom = computed(() => (appStore.cachedPublicSettings?.home_promo_text || '').trim())

// Check if homeContent is a URL (for iframe display)
const isHomeContentUrl = computed(() => {
  const content = homeContent.value.trim()
  return content.startsWith('http://') || content.startsWith('https://')
})

// Stat cards (labels/values resolved via i18n in template)
const stats = ['node', 'encryption', 'uptime', 'support'] as const

// Security & privacy cards
const securityItems = [
  { key: 'noSell', icon: '🔒', bg: 'rgba(20,184,166,0.1)' },
  { key: 'minimalLog', icon: '📋', bg: 'rgba(59,130,246,0.1)' },
  { key: 'keyControl', icon: '🔑', bg: 'rgba(168,85,247,0.1)' },
] as const

// Recharge plans (model IDs are proper nouns; not translated)
interface RechargePlan {
  key: string
  models: string[]
}
const rechargePlans: RechargePlan[] = [
  {
    key: 'claude',
    models: [
      'claude-opus-4-7',
      'claude-opus-4-6',
      'claude-sonnet-4-6',
      'claude-sonnet-4-5',
      'claude-haiku-4-5',
    ],
  },
  {
    key: 'codex',
    models: ['gpt-5.5', 'gpt-image-2', 'gpt-5.4', 'gpt-5.3-codex'],
  },
]

// Steps / FAQ / disclaimer list keys
const steps = ['register', 'createKey', 'integrate'] as const
const faqItems = ['tools', 'security', 'payment', 'support'] as const
const disclaimerItems = ['scope', 'compliance', 'prohibited', 'liability'] as const

// Theme
const isDark = ref(document.documentElement.classList.contains('dark'))

// Auth state
const isAuthenticated = computed(() => authStore.isAuthenticated)
const isAdmin = computed(() => authStore.isAdmin)
const dashboardPath = computed(() => (isAdmin.value ? '/admin/dashboard' : '/dashboard'))
const registerTo = computed(() => (isAuthenticated.value ? dashboardPath.value : '/register'))
const loginTo = computed(() => (isAuthenticated.value ? dashboardPath.value : '/login'))
const userInitial = computed(() => {
  const user = authStore.user
  if (!user || !user.email) return ''
  return user.email.charAt(0).toUpperCase()
})

// Current year for footer
const currentYear = computed(() => new Date().getFullYear())

// Toggle theme
function toggleTheme() {
  isDark.value = !isDark.value
  document.documentElement.classList.toggle('dark', isDark.value)
  localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
}

// Initialize theme
function initTheme() {
  const savedTheme = localStorage.getItem('theme')
  if (
    savedTheme === 'dark' ||
    (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)
  ) {
    isDark.value = true
    document.documentElement.classList.add('dark')
  }
}

onMounted(() => {
  initTheme()

  // Check auth state
  authStore.checkAuth()

  // Ensure public settings are loaded (will use cache if already loaded from injected config)
  if (!appStore.publicSettingsLoaded) {
    appStore.fetchPublicSettings()
  }
})
</script>

<style scoped>
/* Layout styles ported from cda2api-home reference; background stays transparent
   so the page-level gradient & decorations remain visible. */
.cda-home {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  color: #1a1a2e;
  line-height: 1.6;
}
.cda-home * {
  box-sizing: border-box;
}
.cda-home a {
  color: #0d9488;
  text-decoration: none;
}
.cda-home a:hover {
  text-decoration: underline;
}
.cda-home a.cda-btn-primary,
.cda-home a.cda-btn-primary:hover {
  color: #fff !important;
}

/* Hero */
.cda-hero {
  text-align: center;
  padding: 60px 24px 60px;
  position: relative;
  overflow: hidden;
}
.cda-hero-badge {
  display: inline-block;
  background: linear-gradient(135deg, #0d9488, #0891b2);
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  padding: 10px 24px;
  border-radius: 24px;
  margin-bottom: 28px;
  box-shadow: 0 4px 14px rgba(20, 184, 166, 0.3);
  letter-spacing: 0.3px;
}
.cda-hero h1 {
  font-size: clamp(28px, 5vw, 42px);
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 16px;
  line-height: 1.3;
}
.cda-hero h1 span {
  background: linear-gradient(135deg, #0d9488, #06b6d4);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.cda-hero p {
  font-size: 16px;
  color: #64748b;
  max-width: 600px;
  margin: 0 auto 32px;
}
.cda-btn-group {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}
.cda-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 28px;
  border-radius: 10px;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s;
  cursor: pointer;
  border: none;
}
.cda-btn-primary {
  background: linear-gradient(135deg, #0d9488, #14b8a6);
  color: #fff;
  box-shadow: 0 4px 14px rgba(20, 184, 166, 0.3);
  font-weight: 700;
  letter-spacing: 0.5px;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
  font-size: 16px;
}
.cda-btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(20, 184, 166, 0.4);
  color: #fff;
  text-decoration: none;
}
.cda-btn-secondary {
  background: #fff;
  color: #0d9488;
  border: 1px solid #e2e8f0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
.cda-btn-secondary:hover {
  border-color: #0d9488;
  text-decoration: none;
}

/* Stats */
.cda-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 16px;
  max-width: 700px;
  margin: 0 auto;
  padding: 0 24px 60px;
}
.cda-stat-card {
  background: #fff;
  border-radius: 12px;
  padding: 20px 16px;
  text-align: center;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.04);
  border: 1px solid #f1f5f9;
}
.cda-stat-value {
  font-size: 20px;
  font-weight: 700;
  color: #0d9488;
  margin-bottom: 4px;
}
.cda-stat-label {
  font-size: 12px;
  color: #94a3b8;
}

/* Section */
.cda-section {
  padding: 60px 24px;
  max-width: 900px;
  margin: 0 auto;
}
.cda-section-title {
  text-align: center;
  font-size: clamp(22px, 4vw, 28px);
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 12px;
}
.cda-section-desc {
  text-align: center;
  font-size: 15px;
  color: #64748b;
  margin-bottom: 40px;
}

/* Features */
.cda-features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
}
.cda-feature-card {
  background: #fff;
  border-radius: 14px;
  padding: 28px 24px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.04);
  border: 1px solid #f1f5f9;
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}
.cda-feature-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
}
.cda-feature-icon {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  margin: 0 auto 16px;
}
.cda-feature-card h3 {
  font-size: 16px;
  font-weight: 600;
  color: #0f172a;
  margin-bottom: 8px;
}
.cda-feature-card p {
  font-size: 14px;
  color: #64748b;
  line-height: 1.6;
}

/* Recharge / Route Pricing */
.cda-recharge-header {
  text-align: center;
  max-width: 640px;
  margin: 0 auto 40px;
}
.cda-recharge-title {
  font-size: clamp(24px, 4vw, 34px);
  font-weight: 700;
  color: #0f172a;
  line-height: 1.3;
  margin-bottom: 12px;
}
.cda-recharge-lead {
  font-size: 15px;
  color: #64748b;
  line-height: 1.7;
}
.cda-recharge-banner {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  align-items: center;
  background: linear-gradient(135deg, rgba(20, 184, 166, 0.08), rgba(6, 182, 212, 0.06));
  border: 1px solid rgba(20, 184, 166, 0.2);
  border-radius: 16px;
  padding: 20px 24px;
  margin-bottom: 28px;
}
.cda-recharge-banner-tag {
  display: inline-block;
  font-size: 12px;
  font-weight: 600;
  color: #0d9488;
  background: rgba(20, 184, 166, 0.12);
  padding: 3px 10px;
  border-radius: 6px;
  margin-bottom: 10px;
}
.cda-recharge-banner-title {
  font-size: clamp(18px, 3vw, 24px);
  font-weight: 700;
  color: #0f172a;
}
.cda-recharge-banner-desc {
  font-size: 13px;
  color: #64748b;
  line-height: 1.7;
}
.cda-recharge-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 20px;
}
.cda-recharge-card {
  display: flex;
  flex-direction: column;
  background: #fff;
  border: 1px solid #f1f5f9;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.04);
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}
.cda-recharge-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
}
.cda-recharge-card-head {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
}
.cda-recharge-badge {
  font-size: 12px;
  font-weight: 600;
  color: #0d9488;
  background: rgba(20, 184, 166, 0.1);
  border: 1px solid rgba(20, 184, 166, 0.3);
  padding: 2px 10px;
  border-radius: 8px;
}
.cda-recharge-name {
  font-size: 20px;
  font-weight: 700;
  color: #0f172a;
}
.cda-recharge-ratio {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 12px;
}
.cda-recharge-ratio-label {
  font-size: 15px;
  font-weight: 600;
  color: #0d9488;
}
.cda-recharge-ratio-value {
  font-size: 32px;
  font-weight: 800;
  color: #0d9488;
  letter-spacing: 1px;
}
.cda-recharge-desc {
  font-size: 13px;
  color: #64748b;
  line-height: 1.7;
  margin-bottom: 16px;
}
.cda-recharge-models-label {
  font-size: 13px;
  font-weight: 600;
  color: #475569;
  margin-bottom: 10px;
}
.cda-recharge-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 20px;
}
.cda-recharge-chip {
  display: inline-flex;
  align-items: center;
  font-size: 13px;
  font-weight: 500;
  color: #4f46e5;
  background: #fff;
  border: 1px solid #e9edf5;
  border-radius: 8px;
  padding: 6px 12px;
}
.cda-recharge-chip::before {
  content: '\2022';
  color: #8b5cf6;
  margin-right: 6px;
  font-size: 14px;
  line-height: 1;
}
.cda-recharge-btn {
  margin-top: auto;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  background: linear-gradient(135deg, #0d9488, #14b8a6);
  color: #fff !important;
  font-size: 15px;
  font-weight: 700;
  padding: 14px;
  border-radius: 10px;
  box-shadow: 0 4px 14px rgba(20, 184, 166, 0.3);
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}
.cda-recharge-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(20, 184, 166, 0.4);
  color: #fff !important;
  text-decoration: none;
}
@media (max-width: 640px) {
  .cda-recharge-banner {
    grid-template-columns: 1fr;
    gap: 12px;
  }
}

/* Steps */
.cda-steps {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 24px;
}
.cda-step {
  text-align: center;
  padding: 24px 16px;
}
.cda-step-num {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: linear-gradient(135deg, #0d9488, #14b8a6);
  color: #fff;
  font-size: 16px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
}
.cda-step h3 {
  font-size: 15px;
  font-weight: 600;
  color: #0f172a;
  margin-bottom: 8px;
}
.cda-step p {
  font-size: 13px;
  color: #64748b;
}

/* FAQ */
.cda-faq-list {
  max-width: 700px;
  margin: 0 auto;
}
.cda-faq-item {
  background: #fff;
  border-radius: 12px;
  padding: 20px 24px;
  margin-bottom: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.03);
  border: 1px solid #f1f5f9;
}
.cda-faq-item h4 {
  font-size: 15px;
  font-weight: 600;
  color: #0f172a;
  margin-bottom: 8px;
}
.cda-faq-item p {
  font-size: 14px;
  color: #64748b;
}

/* CTA */
.cda-cta {
  text-align: center;
  padding: 60px 24px 80px;
}
.cda-cta h2 {
  font-size: clamp(20px, 4vw, 26px);
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 16px;
}
.cda-cta p {
  font-size: 15px;
  color: #64748b;
  margin-bottom: 28px;
}

/* Disclaimer */
.cda-disclaimer {
  position: relative;
  margin: 0 auto;
  max-width: 860px;
  padding: 0 24px 60px;
}
.cda-disclaimer-inner {
  position: relative;
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  border-radius: 16px;
  padding: 32px 28px;
  border: 1px solid rgba(20, 184, 166, 0.15);
  overflow: hidden;
}
.cda-disclaimer-inner::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, #0d9488, #06b6d4, #8b5cf6);
}
.cda-disclaimer-inner::after {
  content: '';
  position: absolute;
  top: -60px;
  right: -60px;
  width: 160px;
  height: 160px;
  background: radial-gradient(circle, rgba(20, 184, 166, 0.08) 0%, transparent 70%);
  border-radius: 50%;
}
.cda-disclaimer-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
}
.cda-disclaimer-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: rgba(20, 184, 166, 0.15);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
}
.cda-disclaimer-title {
  font-size: 15px;
  font-weight: 600;
  color: #e2e8f0;
  letter-spacing: 0.3px;
}
.cda-disclaimer-body {
  font-size: 13px;
  color: #94a3b8;
  line-height: 1.8;
}
.cda-disclaimer-body p {
  margin-bottom: 10px;
}
.cda-disclaimer-body ul {
  list-style: none;
  padding: 0;
  margin: 12px 0;
}
.cda-disclaimer-body ul li {
  padding: 4px 0;
  padding-left: 20px;
  position: relative;
}
.cda-disclaimer-body ul li::before {
  content: '›';
  position: absolute;
  left: 4px;
  color: #0d9488;
  font-weight: 700;
  font-size: 14px;
}
.cda-disclaimer-highlight {
  color: #67e8f9;
  font-weight: 500;
}
.cda-disclaimer-divider {
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(20, 184, 166, 0.2), transparent);
  margin: 16px 0;
}
.cda-disclaimer-footer {
  font-size: 12px;
  color: #64748b;
  text-align: center;
  margin-top: 12px;
}

/* Promo Banner */
.cda-promo {
  position: relative;
  overflow: hidden;
  background: linear-gradient(120deg, #7c3aed 0%, #0d9488 50%, #0891b2 100%);
  background-size: 200% 100%;
  animation: cda-promo-gradient 6s ease infinite;
  padding: 14px 24px;
  text-align: center;
  box-shadow: 0 4px 20px rgba(124, 58, 237, 0.25);
}
.cda-promo::before {
  content: '';
  position: absolute;
  top: 0;
  left: -60%;
  width: 40%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.35), transparent);
  transform: skewX(-20deg);
  animation: cda-promo-shine 4s ease-in-out infinite;
}
@keyframes cda-promo-gradient {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}
@keyframes cda-promo-shine {
  0% {
    left: -60%;
  }
  60%,
  100% {
    left: 120%;
  }
}
.cda-promo-inner {
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  justify-content: center;
}
.cda-promo-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.45);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  padding: 4px 12px;
  border-radius: 20px;
  letter-spacing: 0.5px;
  white-space: nowrap;
  animation: cda-promo-pulse 1.8s ease-in-out infinite;
}
@keyframes cda-promo-pulse {
  0%,
  100% {
    box-shadow: 0 0 0 0 rgba(255, 255, 255, 0.5);
  }
  50% {
    box-shadow: 0 0 0 7px rgba(255, 255, 255, 0);
  }
}
.cda-promo-text {
  color: #fff;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.25);
}
.cda-promo-text strong {
  color: #fde047;
  font-weight: 800;
}
.cda-promo-cta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: #fff;
  color: #7c3aed !important;
  font-size: 13px;
  font-weight: 700;
  padding: 5px 16px;
  border-radius: 20px;
  transition:
    transform 0.2s,
    box-shadow 0.2s;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}
.cda-promo-cta:hover {
  transform: translateY(-1px);
  color: #7c3aed !important;
  text-decoration: none;
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.2);
}
@media (max-width: 600px) {
  .cda-promo-text {
    font-size: 13px;
  }
}

/* Dark mode */
.dark .cda-home {
  color: #e2e8f0;
}
.dark .cda-hero h1 {
  color: #f8fafc;
}
.dark .cda-hero p,
.dark .cda-section-desc {
  color: #94a3b8;
}
.dark .cda-stat-card,
.dark .cda-feature-card,
.dark .cda-recharge-card,
.dark .cda-faq-item {
  background: #1e293b;
  border-color: #334155;
}
.dark .cda-feature-card h3,
.dark .cda-faq-item h4,
.dark .cda-section-title,
.dark .cda-step h3,
.dark .cda-cta h2,
.dark .cda-recharge-title,
.dark .cda-recharge-name,
.dark .cda-recharge-banner-title {
  color: #f1f5f9;
}
.dark .cda-recharge-lead,
.dark .cda-recharge-desc,
.dark .cda-recharge-banner-desc {
  color: #94a3b8;
}
.dark .cda-recharge-models-label {
  color: #cbd5e1;
}
.dark .cda-recharge-chip {
  background: #0f172a;
  border-color: #334155;
  color: #a5b4fc;
}
.dark .cda-feature-card p,
.dark .cda-faq-item p,
.dark .cda-step p {
  color: #94a3b8;
}
.dark .cda-btn-secondary {
  background: #1e293b;
  border-color: #334155;
  color: #14b8a6;
}
.dark .cda-disclaimer-inner {
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  border-color: rgba(20, 184, 166, 0.2);
}
</style>
