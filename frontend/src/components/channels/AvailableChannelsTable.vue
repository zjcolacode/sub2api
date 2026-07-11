<template>
  <div class="table-wrapper">
    <table class="w-full table-fixed border-collapse text-sm">
      <thead>
        <tr class="border-b border-gray-100 bg-gray-50/50 text-xs font-medium uppercase tracking-wide text-gray-500 dark:border-dark-700 dark:bg-dark-800/50 dark:text-gray-400">
          <th class="w-[180px] px-4 py-3 text-center">{{ columns.name }}</th>
          <th class="w-[200px] px-4 py-3 text-left">{{ columns.description }}</th>
          <th class="w-[140px] px-4 py-3 text-left">{{ columns.platform }}</th>
          <th class="px-4 py-3 text-left">{{ columns.groups }}</th>
          <th class="px-4 py-3 text-left">{{ columns.supportedModels }}</th>
        </tr>
      </thead>
      <tbody v-if="loading">
        <tr>
          <td colspan="5" class="py-10 text-center">
            <Icon name="refresh" size="lg" class="inline-block animate-spin text-gray-400" />
          </td>
        </tr>
      </tbody>
      <tbody v-else-if="rows.length === 0">
        <tr>
          <td colspan="5" class="py-12 text-center">
            <Icon name="inbox" size="xl" class="mx-auto mb-3 h-12 w-12 text-gray-400" />
            <p class="text-sm text-gray-500 dark:text-gray-400">{{ emptyLabel }}</p>
          </td>
        </tr>
      </tbody>
      <!-- 每个渠道一个 tbody：首行 td rowspan 渠道名，后续行只渲染其余三列。
           tbody 之间强分隔线表达"渠道边界"，tbody 内部用淡分隔线区分平台。 -->
      <tbody
        v-else
        v-for="(channel, chIdx) in rows"
        :key="`${channel.name}-${chIdx}`"
        class="border-b-2 border-gray-200 last:border-b-0 dark:border-dark-600"
      >
        <template
          v-for="(section, secIdx) in channel.platforms"
          :key="`${channel.name}-${section.platform}`"
        >
        <tr
          class="transition-colors hover:bg-gray-50/40 dark:hover:bg-dark-800/40"
          :class="{ 'border-t border-gray-100/70 dark:border-dark-700/50': Number(secIdx) > 0 }"
        >
          <!-- 渠道名：只在第一行渲染并用 rowspan 纵向合并（含展开的价格行） -->
          <td
            v-if="secIdx === 0"
            :rowspan="channelRowSpan(channel, chIdx)"
            class="px-4 py-3 text-center align-middle font-medium text-gray-900 dark:text-white"
          >
            {{ channel.name }}
          </td>

          <!-- 描述：独立一列，同样用 rowspan 纵向合并 -->
          <td
            v-if="secIdx === 0"
            :rowspan="channelRowSpan(channel, chIdx)"
            class="px-4 py-3 align-middle text-xs text-gray-500 dark:text-gray-400"
          >
            <template v-if="channel.description">{{ channel.description }}</template>
            <span v-else class="text-gray-400">-</span>
          </td>

          <!-- 平台徽章 -->
          <td class="align-top px-4 py-3">
            <span
              :class="[
                'inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-[11px] font-medium uppercase',
                platformBadgeClass(section.platform),
              ]"
            >
              <PlatformIcon :platform="section.platform as GroupPlatform" size="xs" />
              {{ section.platform }}
            </span>
          </td>

          <!-- 分组：专属分组在前（紫色 shield 行），公开分组在后（灰色 globe 行）。 -->
          <td class="align-top px-4 py-3">
            <div class="flex flex-col gap-1.5">
              <div
                v-if="exclusiveGroups(section).length > 0"
                class="flex flex-wrap items-center gap-1.5"
              >
                <span
                  class="inline-flex items-center gap-0.5 text-[10px] font-medium uppercase text-purple-600 dark:text-purple-400"
                  :title="t('availableChannels.exclusiveTooltip')"
                >
                  <Icon name="shield" size="xs" class="h-3 w-3" />
                  {{ t('availableChannels.exclusive') }}
                </span>
                <GroupBadge
                  v-for="g in exclusiveGroups(section)"
                  :key="`ex-${g.id}`"
                  :name="g.name"
                  :platform="g.platform as GroupPlatform"
                  :subscription-type="(g.subscription_type || 'standard') as SubscriptionType"
                  :rate-multiplier="g.rate_multiplier"
                  :user-rate-multiplier="userGroupRates[g.id] ?? null"
                  always-show-rate
                />
              </div>
              <div
                v-if="publicGroups(section).length > 0"
                class="flex flex-wrap items-center gap-1.5"
              >
                <span
                  class="inline-flex items-center gap-0.5 text-[10px] font-medium uppercase text-gray-500 dark:text-gray-400"
                  :title="t('availableChannels.publicTooltip')"
                >
                  <Icon name="globe" size="xs" class="h-3 w-3" />
                  {{ t('availableChannels.public') }}
                </span>
                <GroupBadge
                  v-for="g in publicGroups(section)"
                  :key="`pub-${g.id}`"
                  :name="g.name"
                  :platform="g.platform as GroupPlatform"
                  :subscription-type="(g.subscription_type || 'standard') as SubscriptionType"
                  :rate-multiplier="g.rate_multiplier"
                  :user-rate-multiplier="userGroupRates[g.id] ?? null"
                  always-show-rate
                />
              </div>
              <span v-if="section.groups.length === 0" class="text-xs text-gray-400">-</span>
            </div>
          </td>

          <!-- 支持模型 -->
          <td class="align-top px-4 py-3">
            <div class="flex items-start gap-2">
              <button
                v-if="section.supported_models.length > 0"
                type="button"
                class="mt-0.5 inline-flex flex-shrink-0 items-center gap-1 rounded-md border border-gray-200 px-1.5 py-0.5 text-[11px] font-medium text-gray-500 transition-colors hover:border-primary-300 hover:text-primary-600 dark:border-dark-600 dark:text-gray-400 dark:hover:border-primary-500 dark:hover:text-primary-400"
                :title="isExpanded(chIdx, secIdx) ? t('availableChannels.pricing.hidePricing') : t('availableChannels.pricing.viewPricing')"
                @click="toggle(chIdx, secIdx)"
              >
                <Icon
                  :name="isExpanded(chIdx, secIdx) ? 'chevronUp' : 'chevronDown'"
                  size="xs"
                  class="h-3 w-3"
                />
                {{ isExpanded(chIdx, secIdx) ? t('availableChannels.pricing.hidePricing') : t('availableChannels.pricing.viewPricing') }}
              </button>
              <div class="flex flex-wrap gap-1">
                <SupportedModelChip
                  v-for="m in section.supported_models"
                  :key="`${section.platform}-${m.name}`"
                  :model="m"
                  :pricing-key-prefix="pricingKeyPrefix"
                  :no-pricing-label="noPricingLabel"
                  :show-platform="false"
                  :platform-hint="section.platform"
                />
                <span v-if="section.supported_models.length === 0" class="text-xs text-gray-400">
                  {{ noModelsLabel }}
                </span>
              </div>
            </div>
          </td>
        </tr>

        <!-- 展开的价格表行：仅渲染平台/分组/支持模型三列（渠道名、描述由 rowspan 覆盖） -->
        <tr
          v-if="isExpanded(chIdx, secIdx)"
          class="bg-gray-50/60 dark:bg-dark-800/30"
        >
          <td colspan="3" class="px-4 pb-4 pt-0 align-top">
            <ModelPricingTable
              :models="section.supported_models"
              :pricing-key-prefix="pricingKeyPrefix"
              :no-pricing-label="noPricingLabel"
              :platform-hint="section.platform"
            />
          </td>
        </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import Icon from '@/components/icons/Icon.vue'
import PlatformIcon from '@/components/common/PlatformIcon.vue'
import GroupBadge from '@/components/common/GroupBadge.vue'
import SupportedModelChip from './SupportedModelChip.vue'
import ModelPricingTable from './ModelPricingTable.vue'
import type { UserAvailableChannel, UserAvailableGroup, UserChannelPlatformSection } from '@/api/channels'
import type { GroupPlatform, SubscriptionType } from '@/types'
import { platformBadgeClass } from '@/utils/platformColors'

const props = defineProps<{
  columns: {
    name: string
    description: string
    platform: string
    groups: string
    supportedModels: string
  }
  rows: UserAvailableChannel[]
  loading: boolean
  pricingKeyPrefix: string
  noPricingLabel: string
  noModelsLabel: string
  emptyLabel: string
  /** 用户专属倍率（group_id → multiplier）；无专属时由 GroupBadge 仅显示默认倍率。 */
  userGroupRates: Record<number, number>
}>()

// Suppress unused warning — props is accessed via template automatically but
// the explicit reference here keeps the linter from flagging userGroupRates.
void props.userGroupRates

const { t } = useI18n()

function exclusiveGroups(section: UserChannelPlatformSection): UserAvailableGroup[] {
  return section.groups.filter((g) => g.is_exclusive)
}

function publicGroups(section: UserChannelPlatformSection): UserAvailableGroup[] {
  return section.groups.filter((g) => !g.is_exclusive)
}

// ── 价格表展开状态 ──────────────────────────────────────────────
// 以 `${chIdx}-${secIdx}` 为键记录哪些平台分区展开了价格表。
// 每个渠道可有多个平台分区，各自独立展开/折叠。
const expanded = ref<Set<string>>(new Set())

function sectionKey(chIdx: number, secIdx: number): string {
  return `${chIdx}-${secIdx}`
}

function isExpanded(chIdx: number, secIdx: number): boolean {
  return expanded.value.has(sectionKey(chIdx, secIdx))
}

function toggle(chIdx: number, secIdx: number): void {
  const key = sectionKey(chIdx, secIdx)
  const next = new Set(expanded.value)
  if (next.has(key)) {
    next.delete(key)
  } else {
    next.add(key)
  }
  expanded.value = next
}

/**
 * 渠道名/描述列的 rowspan：等于该渠道全部渲染行数。
 * 每个平台分区占 1 行，展开价格表时再 +1 行，确保纵向合并覆盖价格行。
 */
function channelRowSpan(channel: UserAvailableChannel, chIdx: number): number {
  return channel.platforms.reduce(
    (sum, _section, secIdx) => sum + (isExpanded(chIdx, secIdx) ? 2 : 1),
    0
  )
}

</script>
