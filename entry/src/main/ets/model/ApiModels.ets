/**
 * 分类接口返回模型
 */
export class CategoryDto {
  id: number
  name: string
  logo: string

  constructor(id: number, name: string, logo: string) {
    this.id = id
    this.name = name
    this.logo = logo
  }
}

/**
 * 手势接口返回模型
 */
export class GestureItemDto {
  id: number
  categoryId: number
  chineseName: string
  label: string

  constructor(id: number, categoryId: number, chineseName: string, label: string) {
    this.id = id
    this.categoryId = categoryId
    this.chineseName = chineseName
    this.label = label
  }
}