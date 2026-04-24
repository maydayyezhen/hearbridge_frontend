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
