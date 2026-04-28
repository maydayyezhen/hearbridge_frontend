export class CategoryDto {
  id: number
  code: string
  nameZh: string
  coverObjectKey: string
  coverUrl: string

  constructor(id: number, code: string, nameZh: string, coverObjectKey: string, coverUrl: string) {
    this.id = id
    this.code = code
    this.nameZh = nameZh
    this.coverObjectKey = coverObjectKey
    this.coverUrl = coverUrl
  }
}

export class GestureItemDto {
  id: number
  code: string
  nameZh: string
  categoryCode: string
  sigmlObjectKey: string
  coverObjectKey: string
  sigmlUrl: string
  coverUrl: string

  constructor(
    id: number,
    code: string,
    nameZh: string,
    categoryCode: string,
    sigmlObjectKey: string,
    coverObjectKey: string,
    sigmlUrl: string,
    coverUrl: string
  ) {
    this.id = id
    this.code = code
    this.nameZh = nameZh
    this.categoryCode = categoryCode
    this.sigmlObjectKey = sigmlObjectKey
    this.coverObjectKey = coverObjectKey
    this.sigmlUrl = sigmlUrl
    this.coverUrl = coverUrl
  }
}

/**
 * 通用分页结果。
 */
export class PageResultDto<T> {
  /** 当前页数据。 */
  records: T[]
  /** 总记录数。 */
  total: number
  /** 当前页码。 */
  pageNo: number
  /** 每页数量。 */
  pageSize: number
  /** 总页数。 */
  totalPages: number
  /** 是否还有下一页。 */
  hasNext: boolean

  constructor(records: T[], total: number, pageNo: number, pageSize: number, totalPages: number, hasNext: boolean) {
    this.records = records
    this.total = total
    this.pageNo = pageNo
    this.pageSize = pageSize
    this.totalPages = totalPages
    this.hasNext = hasNext
  }
}

/**
 * 手语训练统一搜索结果。
 */
export class SignSearchResultDto {
  /** 搜索关键词。 */
  keyword: string
  /** 匹配分类分页结果。 */
  categories: PageResultDto<CategoryDto>
  /** 匹配手势资源分页结果。 */
  resources: PageResultDto<GestureItemDto>

  constructor(
    keyword: string,
    categories: PageResultDto<CategoryDto>,
    resources: PageResultDto<GestureItemDto>
  ) {
    this.keyword = keyword
    this.categories = categories
    this.resources = resources
  }
}

export class AuthUserDto {
  id: number
  username: string
  nickname: string
  avatarUrl: string

  constructor(id: number, username: string, nickname: string, avatarUrl: string) {
    this.id = id
    this.username = username
    this.nickname = nickname
    this.avatarUrl = avatarUrl
  }
}

export class AuthResponseDto {
  token: string
  user: AuthUserDto

  constructor(token: string, user: AuthUserDto) {
    this.token = token
    this.user = user
  }
}
