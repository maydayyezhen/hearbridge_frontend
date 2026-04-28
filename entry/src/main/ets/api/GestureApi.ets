import { HttpClient } from '../common/http/HttpClient'
import { AppConfig } from '../common/constants/AppConfig'
import { CategoryDto, GestureItemDto, PageResultDto, SignSearchResultDto } from '../model/ApiModels'

export class GestureApi {
  static async getCategories(): Promise<CategoryDto[]> {
    const text = await HttpClient.get('/sign/categories')
    const rawList = JSON.parse(text) as Array<Object>
    const result: CategoryDto[] = []

    rawList.forEach((item: Object) => {
      result.push(GestureApi.parseCategory(item))
    })

    return result
  }

  /**
   * 分页查询手语分类。
   *
   * @param pageNo 当前页码
   * @param pageSize 每页数量
   * @returns 分类分页结果
   */
  static async getCategoriesPage(pageNo: number, pageSize: number): Promise<PageResultDto<CategoryDto>> {
    const text = await HttpClient.get(`/sign/categories/page?pageNo=${pageNo}&pageSize=${pageSize}`)
    const raw = JSON.parse(text) as Record<string, Object>
    return GestureApi.parsePageResult(raw, (item: Object): CategoryDto => GestureApi.parseCategory(item))
  }

  static async getGestureItems(categoryCode: string): Promise<GestureItemDto[]> {
    const text = await HttpClient.get(`/sign/resources?categoryCode=${encodeURIComponent(categoryCode)}`)
    const rawList = JSON.parse(text) as Array<Object>
    const result: GestureItemDto[] = []

    rawList.forEach((item: Object) => {
      result.push(GestureApi.parseGestureItem(item))
    })

    return result
  }

  /**
   * 分页查询手势资源。
   *
   * @param categoryCode 分类编码
   * @param pageNo 当前页码
   * @param pageSize 每页数量
   * @returns 资源分页结果
   */
  static async getGestureItemsPage(
    categoryCode: string,
    pageNo: number,
    pageSize: number
  ): Promise<PageResultDto<GestureItemDto>> {
    const query = categoryCode.trim().length > 0
      ? `categoryCode=${encodeURIComponent(categoryCode)}&pageNo=${pageNo}&pageSize=${pageSize}`
      : `pageNo=${pageNo}&pageSize=${pageSize}`
    const text = await HttpClient.get(`/sign/resources/page?${query}`)
    const raw = JSON.parse(text) as Record<string, Object>
    return GestureApi.parsePageResult(raw, (item: Object): GestureItemDto => GestureApi.parseGestureItem(item))
  }

  /**
   * 搜索手语分类和手势资源。
   *
   * @param keyword 搜索关键词
   * @param pageNo 当前页码
   * @param pageSize 每页数量
   * @returns 分类与手势资源搜索结果
   */
  static async search(keyword: string, pageNo: number = 1, pageSize: number = 20): Promise<SignSearchResultDto> {
    const trimmedKeyword = keyword.trim()
    if (trimmedKeyword.length === 0) {
      return new SignSearchResultDto(
        '',
        new PageResultDto<CategoryDto>([], 0, pageNo, pageSize, 0, false),
        new PageResultDto<GestureItemDto>([], 0, pageNo, pageSize, 0, false)
      )
    }

    const text = await HttpClient.get(
      `/sign/search?keyword=${encodeURIComponent(trimmedKeyword)}&pageNo=${pageNo}&pageSize=${pageSize}`
    )
    const raw = JSON.parse(text) as Record<string, Object>
    const rawCategories = GestureApi.readRecord(raw, 'categories')
    const rawResources = GestureApi.readRecord(raw, 'resources')

    return new SignSearchResultDto(
      GestureApi.readString(raw, 'keyword'),
      GestureApi.parsePageResult(rawCategories, (item: Object): CategoryDto => GestureApi.parseCategory(item)),
      GestureApi.parsePageResult(rawResources, (item: Object): GestureItemDto => GestureApi.parseGestureItem(item))
    )
  }

  /**
   * 解析分类 DTO。
   *
   * @param item 原始对象
   * @returns 分类 DTO
   */
  private static parseCategory(item: Object): CategoryDto {
    const obj = item as Record<string, Object>
    const coverObjectKey = GestureApi.readString(obj, 'coverObjectKey')
    const coverUrl = AppConfig.normalizeAssetUrl(
      GestureApi.readString(obj, 'coverUrl'),
      coverObjectKey
    )

    return new CategoryDto(
      GestureApi.readNumber(obj, 'id'),
      GestureApi.readString(obj, 'code'),
      GestureApi.readString(obj, 'nameZh'),
      coverObjectKey,
      coverUrl
    )
  }

  /**
   * 解析手势资源 DTO。
   *
   * @param item 原始对象
   * @returns 手势资源 DTO
   */
  private static parseGestureItem(item: Object): GestureItemDto {
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

    return new GestureItemDto(
      GestureApi.readNumber(obj, 'id'),
      GestureApi.readString(obj, 'code'),
      GestureApi.readString(obj, 'nameZh'),
      GestureApi.readString(obj, 'categoryCode'),
      sigmlObjectKey,
      coverObjectKey,
      sigmlUrl,
      coverUrl
    )
  }

  /**
   * 解析分页结果。
   *
   * @param source 原始分页对象
   * @param parser 单条记录解析器
   * @returns 分页结果
   */
  private static parsePageResult<T>(source: Record<string, Object>, parser: (item: Object) => T): PageResultDto<T> {
    const records: T[] = []
    const rawRecords = GestureApi.readArray(source, 'records')

    rawRecords.forEach((item: Object) => {
      records.push(parser(item))
    })

    return new PageResultDto<T>(
      records,
      GestureApi.readNumber(source, 'total'),
      GestureApi.readNumber(source, 'pageNo'),
      GestureApi.readNumber(source, 'pageSize'),
      GestureApi.readNumber(source, 'totalPages'),
      GestureApi.readBoolean(source, 'hasNext')
    )
  }

  private static readArray(source: Record<string, Object>, key: string): Object[] {
    const value = source[key]
    if (Array.isArray(value)) {
      return value as Object[]
    }
    return []
  }

  private static readRecord(source: Record<string, Object>, key: string): Record<string, Object> {
    const value = source[key]
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object>
    }
    return {}
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

  private static readBoolean(source: Record<string, Object>, key: string): boolean {
    const value = source[key]
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'string') {
      return value === 'true'
    }
    return false
  }
}
