/**
 * 手势分类模型
 */
export class GestureCategory {
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
 * 手势条目模型
 */
export class GestureItem {
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

/**
 * 手势列表页参数
 */
export class GestureListPageParams {
  categoryId: number
  categoryName: string

  constructor(categoryId: number, categoryName: string) {
    this.categoryId = categoryId
    this.categoryName = categoryName
  }
}

/**
 * 手势训练页参数
 */
export class GesturePracticePageParams {
  gestureId: number
  chineseName: string
  label: string

  constructor(gestureId: number, chineseName: string, label: string) {
    this.gestureId = gestureId
    this.chineseName = chineseName
    this.label = label
  }
}

/**
 * 构造分类数据
 */
export function buildCategoryList(): GestureCategory[] {
  return [
    new GestureCategory(1, '数字', 'number'),
    new GestureCategory(2, '基础手势', 'gesture')
  ]
}

/**
 * 根据分类ID构造手势列表
 */
export function buildGestureListByCategoryId(categoryId: number): GestureItem[] {
  if (categoryId === 1) {
    return []
  }

  if (categoryId === 2) {
    return [
      new GestureItem(1, 2, '过去', 'away'),
      new GestureItem(2, 2, '打电话', 'call'),
      new GestureItem(3, 2, '过来', 'come'),
      new GestureItem(4, 2, '你好', 'hello'),
      new GestureItem(5, 2, '好的', 'ok'),
      new GestureItem(6, 2, '谢谢', 'thank_you')
    ]
  }

  return []
}