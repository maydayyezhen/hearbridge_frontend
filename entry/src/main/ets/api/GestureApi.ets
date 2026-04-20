import { HttpClient } from '../common/http/HttpClient'
import { CategoryDto, GestureItemDto } from '../model/ApiModels'

/**
 * 手势相关 API
 */
export class GestureApi {
  /**
   * 查询分类列表
   */
  static async getCategories(): Promise<CategoryDto[]> {
    const text = await HttpClient.get('/gesture/categories')
    const rawList = JSON.parse(text) as Array<Object>
    const result: CategoryDto[] = []

    rawList.forEach((item: Object) => {
      const obj = item as Record<string, Object>
      result.push(
        new CategoryDto(
          Number(obj['id']),
          String(obj['name']),
          String(obj['logo'])
        )
      )
    })

    return result
  }

  /**
   * 根据分类ID查询手势列表
   */
  static async getGestureItems(categoryId: number): Promise<GestureItemDto[]> {
    const text = await HttpClient.get(`/gesture/items?categoryId=${categoryId}`)
    const rawList = JSON.parse(text) as Array<Object>
    const result: GestureItemDto[] = []

    rawList.forEach((item: Object) => {
      const obj = item as Record<string, Object>
      result.push(
        new GestureItemDto(
          Number(obj['id']),
          Number(obj['categoryId']),
          String(obj['chineseName']),
          String(obj['label'])
        )
      )
    })

    return result
  }
}