import { AuthApi } from '../../api/AuthApi'
import { getStoredToken } from '../auth/AuthStorage'
import { RecentPracticeDto } from '../../model/ApiModels'

/**
 * 清空最近练习本地状态。
 */
export function clearRecentPracticeLocal(): void {
  AppStorage.setOrCreate('recent.practice.id', 0)
  AppStorage.setOrCreate('recent.practice.code', '')
  AppStorage.setOrCreate('recent.practice.name', '')
  AppStorage.setOrCreate('recent.practice.sigmlUrl', '')
  AppStorage.setOrCreate('recent.practice.coverUrl', '')
}

/**
 * 保存最近练习到 AppStorage。
 */
export function saveRecentPracticeLocal(
  resourceId: number,
  resourceCode: string,
  chineseName: string,
  sigmlUrl: string,
  coverUrl: string
): void {
  AppStorage.setOrCreate('recent.practice.id', resourceId)
  AppStorage.setOrCreate('recent.practice.code', resourceCode)
  AppStorage.setOrCreate('recent.practice.name', chineseName)
  AppStorage.setOrCreate('recent.practice.sigmlUrl', sigmlUrl)
  AppStorage.setOrCreate('recent.practice.coverUrl', coverUrl)
}

/**
 * 根据后端 DTO 应用最近练习。
 */
export function applyRecentPracticeDto(practice: RecentPracticeDto): void {
  if (practice.resourceCode.trim().length === 0) {
    clearRecentPracticeLocal()
    return
  }

  saveRecentPracticeLocal(
    practice.resourceId,
    practice.resourceCode,
    practice.chineseName.trim().length > 0 ? practice.chineseName : practice.resourceCode,
    practice.sigmlUrl,
    practice.coverUrl
  )
}

/**
 * 启动时从后端恢复最近练习。
 */
export async function restoreRecentPracticeFromBackend(): Promise<void> {
  if (getStoredToken().trim().length === 0) {
    clearRecentPracticeLocal()
    return
  }

  try {
    const practice = await AuthApi.getRecentPractice()
    applyRecentPracticeDto(practice)
  } catch (error) {
    console.error(`[RecentPracticeStorage] restore failed: ${JSON.stringify(error)}`)
  }
}

/**
 * 保存最近练习到本地，并异步同步到后端。
 */
export async function saveRecentPracticeLocalAndSync(
  resourceId: number,
  resourceCode: string,
  chineseName: string,
  sigmlUrl: string,
  coverUrl: string
): Promise<void> {
  const safeName = chineseName.trim().length > 0 ? chineseName : resourceCode

  saveRecentPracticeLocal(
    resourceId,
    resourceCode,
    safeName,
    sigmlUrl,
    coverUrl
  )

  if (getStoredToken().trim().length === 0 || resourceCode.trim().length === 0) {
    return
  }

  try {
    await AuthApi.updateRecentPractice(
      new RecentPracticeDto(
        resourceId,
        resourceCode,
        safeName,
        sigmlUrl,
        coverUrl
      )
    )
  } catch (error) {
    console.error(`[RecentPracticeStorage] sync failed: ${JSON.stringify(error)}`)
  }
}