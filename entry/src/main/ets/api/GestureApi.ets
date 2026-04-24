import { HttpClient } from '../common/http/HttpClient'
import { AppConfig } from '../common/constants/AppConfig'
import { CategoryDto, GestureItemDto } from '../model/ApiModels'

export class GestureApi {
  static async getCategories(): Promise<CategoryDto[]> {
    const text = await HttpClient.get('/sign/categories')
    const rawList = JSON.parse(text) as Array<Object>
    const result: CategoryDto[] = []

    rawList.forEach((item: Object) => {
      const obj = item as Record<string, Object>
      const coverObjectKey = GestureApi.readString(obj, 'coverObjectKey')
      const coverUrl = AppConfig.normalizeAssetUrl(
        GestureApi.readString(obj, 'coverUrl'),
        coverObjectKey
      )

      result.push(
        new CategoryDto(
          GestureApi.readNumber(obj, 'id'),
          GestureApi.readString(obj, 'code'),
          GestureApi.readString(obj, 'nameZh'),
          coverObjectKey,
          coverUrl
        )
      )
    })

    return result
  }

  static async getGestureItems(categoryCode: string): Promise<GestureItemDto[]> {
    const text = await HttpClient.get(`/sign/resources?categoryCode=${encodeURIComponent(categoryCode)}`)
    const rawList = JSON.parse(text) as Array<Object>
    const result: GestureItemDto[] = []

    rawList.forEach((item: Object) => {
      const obj = item as Record<string, Object>
      const sigmlObjectKey = GestureApi.readString(obj, 'sigmlObjectKey')
      const coverObjectKey = GestureApi.readString(obj, 'coverObjectKey')
      const sigmlUrl = AppConfig.normalizeAssetUrl(
        GestureApi.readString(obj, 'sigmlUrl'),
        sigmlObjectKey
      )
      const coverUrl = AppConfig.normalizeAssetUrl(
        GestureApi.readString(obj, 'coverUrl'),
        coverObjectKey
      )

      result.push(
        new GestureItemDto(
          GestureApi.readNumber(obj, 'id'),
          GestureApi.readString(obj, 'code'),
          GestureApi.readString(obj, 'nameZh'),
          GestureApi.readString(obj, 'categoryCode'),
          sigmlObjectKey,
          coverObjectKey,
          sigmlUrl,
          coverUrl
        )
      )
    })

    return result
  }

  private static readString(source: Record<string, Object>, key: string): string {
    const value = source[key]
    if (typeof value === 'string') {
      return value
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value)
    }
    return ''
  }

  private static readNumber(source: Record<string, Object>, key: string): number {
    const value = source[key]
    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value)
      return Number.isFinite(parsed) ? parsed : 0
    }
    return 0
  }
}
