<template>
  <div class="overflow-x-auto rounded-lg border border-gray-200 dark:border-dark-600">
    <table class="w-full min-w-[560px] border-collapse text-xs">
      <thead>
        <tr class="border-b border-gray-200 bg-gray-100/70 text-[11px] font-medium uppercase tracking-wide text-gray-500 dark:border-dark-600 dark:bg-dark-700/60 dark:text-gray-400">
          <th class="px-3 py-2 text-left">{{ t(prefixKey('modelName')) }}</th>
          <th class="px-3 py-2 text-left">{{ t(prefixKey('billingMode')) }}</th>
          <th class="px-3 py-2 !text-right">{{ t(prefixKey('inputPrice')) }}</th>
          <th class="px-3 py-2 !text-right">{{ t(prefixKey('outputPrice')) }}</th>
          <th class="px-3 py-2 !text-right">{{ t(prefixKey('cacheWritePrice')) }}</th>
          <th class="px-3 py-2 !text-right">{{ t(prefixKey('cacheReadPrice')) }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(m, idx) in models"
          :key="`${m.platform}-${m.name}-${idx}`"
          class="border-b border-gray-100 last:border-b-0 dark:border-dark-700/60"
        >
          <td class="px-3 py-2 text-left font-medium text-gray-900 dark:text-white">
            <span class="inline-flex items-center gap-1">
              <PlatformIcon
                v-if="m.platform || platformHint"
                :platform="(m.platform || platformHint) as GroupPlatform"
                size="xs"
              />
              {{ m.name }}
            </span>
          </td>

          <!-- 无定价：整行价格列合并展示提示 -->
          <template v-if="!m.pricing">
            <td class="px-3 py-2 text-left text-gray-400">-</td>
            <td class="px-3 py-2 text-center text-gray-400" colspan="4">
              {{ noPricingLabel || t(prefixKey('noPricing')) }}
            </td>
          </template>

          <template v-else>
            <td class="px-3 py-2 text-left text-gray-600 dark:text-gray-300">
              {{ billingModeLabel(m.pricing.billing_mode) }}
            </td>

            <!-- 按 Token 计费：四列价格 -->
            <template v-if="m.pricing.billing_mode === BILLING_MODE_TOKEN">
              <td class="px-3 py-2 text-right font-mono text-gray-700 dark:text-gray-300">
                {{ fmt(m.pricing.input_price) }}
              </td>
              <td class="px-3 py-2 text-right font-mono text-gray-700 dark:text-gray-300">
                {{ fmt(m.pricing.output_price) }}
              </td>
              <td class="px-3 py-2 text-right font-mono text-gray-700 dark:text-gray-300">
                {{ fmt(m.pricing.cache_write_price) }}
              </td>
              <td class="px-3 py-2 text-right font-mono text-gray-700 dark:text-gray-300">
                {{ fmt(m.pricing.cache_read_price) }}
              </td>
            </template>

            <!-- 按次 / 按图片计费：合并单元格展示单一价格 -->
            <td
              v-else
              class="px-3 py-2 text-right font-mono text-gray-700 dark:text-gray-300"
              colspan="4"
            >
              {{ specialPriceLabel(m.pricing) }}
            </td>
          </template>
        </tr>
      </tbody>
    </table>
    <p class="px-3 py-2 text-[11px] text-gray-400 dark:text-gray-500">
      {{ t(prefixKey('unitPerMillion')) }} · USD
    </p>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { formatScaled } from '@/utils/pricing'
import {
  BILLING_MODE_TOKEN,
  BILLING_MODE_PER_REQUEST,
  BILLING_MODE_IMAGE,
} from '@/constants/channel'
import type { UserSupportedModel, UserSupportedModelPricing } from '@/api/channels'
import PlatformIcon from '@/components/common/PlatformIcon.vue'
import type { GroupPlatform } from '@/types'

const props = withDefaults(
  defineProps<{
    models: UserSupportedModel[]
    /** i18n 前缀：与 SupportedModelChip 保持一致，用户端传 `availableChannels.pricing`。 */
    pricingKeyPrefix?: string
    noPricingLabel?: string
    /** 当 model.platform 缺失时用父行平台兜底着色。 */
    platformHint?: string
  }>(),
  {
    pricingKeyPrefix: 'availableChannels.pricing',
    noPricingLabel: '',
    platformHint: '',
  }
)

const { t } = useI18n()

/** 按 token 定价展示时的换算单位：每百万 token。 */
const perMillionScale = 1_000_000

function prefixKey(k: string): string {
  return `${props.pricingKeyPrefix}.${k}`
}

function fmt(value: number | null): string {
  return formatScaled(value, perMillionScale)
}

function billingModeLabel(mode: string): string {
  switch (mode) {
    case BILLING_MODE_TOKEN:
      return t(prefixKey('billingModeToken'))
    case BILLING_MODE_PER_REQUEST:
      return t(prefixKey('billingModePerRequest'))
    case BILLING_MODE_IMAGE:
      return t(prefixKey('billingModeImage'))
    default:
      return '-'
  }
}

/** 按次 / 按图片计费的单一价格展示（含单位）。 */
function specialPriceLabel(pricing: UserSupportedModelPricing): string {
  if (pricing.billing_mode === BILLING_MODE_PER_REQUEST) {
    const price = formatScaled(pricing.per_request_price, 1)
    return `${price} ${t(prefixKey('unitPerRequest'))}`
  }
  if (pricing.billing_mode === BILLING_MODE_IMAGE) {
    const price = formatScaled(pricing.image_output_price, 1)
    return `${price} ${t(prefixKey('unitPerRequest'))}`
  }
  return '-'
}
</script>
