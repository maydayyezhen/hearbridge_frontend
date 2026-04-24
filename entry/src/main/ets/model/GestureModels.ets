export class GestureListPageParams {
  categoryCode: string
  categoryName: string

  constructor(categoryCode: string, categoryName: string) {
    this.categoryCode = categoryCode
    this.categoryName = categoryName
  }
}

export class GesturePracticePageParams {
  resourceId: number
  resourceCode: string
  chineseName: string
  sigmlUrl: string
  coverUrl: string

  constructor(
    resourceId: number,
    resourceCode: string,
    chineseName: string,
    sigmlUrl: string,
    coverUrl: string
  ) {
    this.resourceId = resourceId
    this.resourceCode = resourceCode
    this.chineseName = chineseName
    this.sigmlUrl = sigmlUrl
    this.coverUrl = coverUrl
  }
}
