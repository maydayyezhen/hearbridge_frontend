import { router } from '@kit.ArkUI'
import { CategoryDto } from '../../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#FFFFFF'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'
const BORDER: string = '#E5EAF3'

/**
 * 首页根 Tab。
 *
 * 说明：
 * 1. 顶部 Hero 使用本地图片作为背景。
 * 2. Hero 不放按钮，只展示品牌标题与副标题。
 * 3. 标题使用 ArkUI 官方文本描边能力，白字 + 灰蓝描边。
 * 4. 下方内容统一采用线性列表风格。
 */
@Component
export struct HomeRootTab {
  /** 后端返回的手语分类列表。 */
  @Prop categories: CategoryDto[] = []

  /** 分类是否正在加载。 */
  @Prop loading: boolean = false

  /** 分类加载错误文案。 */
  @Prop errorText: string = ''

  /** 打开训练 Tab 回调。 */
  onOpenTrainingTab: () => void = () => {}

  /** 最近练习 ID。 */
  @StorageLink('recent.practice.id') recentPracticeId: number = 0

  /** 最近练习编码。 */
  @StorageLink('recent.practice.code') recentPracticeCode: string = ''

  /** 最近练习名称。 */
  @StorageLink('recent.practice.name') recentPracticeName: string = ''

  /** 最近练习 SiGML 地址。 */
  @StorageLink('recent.practice.sigmlUrl') recentPracticeSigmlUrl: string = ''

  /** 最近练习封面地址。 */
  @StorageLink('recent.practice.coverUrl') recentPracticeCoverUrl: string = ''

  /**
   * 是否存在最近练习。
   */
  private hasRecentPractice(): boolean {
    return this.recentPracticeCode.trim().length > 0 && this.recentPracticeSigmlUrl.trim().length > 0
  }

  /**
   * 获取最近练习标题。
   */
  private getRecentPracticeTitle(): string {
    return this.recentPracticeName.trim().length > 0 ? this.recentPracticeName : this.recentPracticeCode
  }

  /**
   * 打开分类资源列表页。
   */
  private openCategory(item: CategoryDto): void {
    try {
      const params: GestureListPageParams = new GestureListPageParams(item.code, item.nameZh)

      router.pushUrl({
        url: 'pages/GestureListPage',
        params: params
      }).catch((err: Object) => {
        console.error(`[HomeRootTab] open category failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[HomeRootTab] open category exception: ${JSON.stringify(err)}`)
    }
  }

  /**
   * 继续最近练习；如果没有最近练习，则进入第一个分类或训练 Tab。
   */
  private continueRecentPractice(): void {
    if (!this.hasRecentPractice()) {
      if (this.categories.length > 0) {
        this.openCategory(this.categories[0])
      } else {
        this.onOpenTrainingTab()
      }
      return
    }

    try {
      const params: GesturePracticePageParams = new GesturePracticePageParams(
        this.recentPracticeId,
        this.recentPracticeCode,
        this.getRecentPracticeTitle(),
        this.recentPracticeSigmlUrl,
        this.recentPracticeCoverUrl
      )

      router.pushUrl({
        url: 'pages/GesturePracticePageRefactored',
        params: params
      }).catch((err: Object) => {
        console.error(`[HomeRootTab] continue practice failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[HomeRootTab] continue practice exception: ${JSON.stringify(err)}`)
    }
  }

  /**
   * 构建分类字标。
   */
  private buildBadgeText(item: CategoryDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'S'
  }

  /**
   * 获取首页展示的常用分类。
   */
  private getFeaturedCategories(): CategoryDto[] {
    return this.categories.slice(0, 4)
  }

  /**
   * 构建模拟描边文字。
   *
   * 说明：
   * 当前 ArkUI SDK 若不支持 strokeColor / strokeWidth，
   * 可以用四向偏移文字模拟描边效果。
   */
  @Builder
  private buildOutlinedHeroText(
    content: string,
    fontSize: number,
    outlineColor: string,
    fillColor: string,
    weight: FontWeight
  ): void {
    Stack() {
      Text(content)
        .fontSize(fontSize)
        .fontWeight(weight)
        .fontColor(outlineColor)
        .translate({ x: -1, y: 0 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(content)
        .fontSize(fontSize)
        .fontWeight(weight)
        .fontColor(outlineColor)
        .translate({ x: 1, y: 0 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(content)
        .fontSize(fontSize)
        .fontWeight(weight)
        .fontColor(outlineColor)
        .translate({ x: 0, y: -1 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(content)
        .fontSize(fontSize)
        .fontWeight(weight)
        .fontColor(outlineColor)
        .translate({ x: 0, y: 1 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(content)
        .fontSize(fontSize)
        .fontWeight(weight)
        .fontColor(fillColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  /**
   * 构建顶部图片 Hero。
   *
   * 注意：
   * 需要将不带文字的背景图放到：
   * entry/src/main/resources/base/media/home_hero_bg.png
   */
  /**
   * 构建顶部图片 Hero。
   *
   * 注意：
   * 需要将不带文字的背景图放到：
   * entry/src/main/resources/base/media/home_hero_bg.png
   */
  @Builder
  private buildHeroCard(): void {
    Stack() {
      Image($r('app.media.home_hero_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [
          ['rgba(255,255,255,0.02)', 0.0],
          ['rgba(255,255,255,0.00)', 0.45],
          ['rgba(255,255,255,0.12)', 1.0]
        ]
      })

      Column({ space: 8 }) {
        this.buildOutlinedHeroText(
          '听桥 HearBridge',
          34,
          'rgba(92,112,138,0.82)',
          '#FFFFFF',
          FontWeight.Bold
        )

        this.buildOutlinedHeroText(
          '连接沟通 · 手语训练',
          16,
          'rgba(92,112,138,0.76)',
          '#FFFFFF',
          FontWeight.Medium
        )
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 24 })
    }
    .width('100%')
    .height(178)
    .borderRadius(28)
    .clip(true)
    .backgroundColor('#F3F6FB')
  }

  /**
   * 构建继续练习区域。
   */
  @Builder
  private buildContinueCard(): void {
    Column({ space: 0 }) {
      Row() {
        Text('继续练习')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Blank()
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      Row({ space: 14 }) {
        if (this.recentPracticeCoverUrl.trim().length > 0) {
          Image(this.recentPracticeCoverUrl)
            .width(44)
            .height(44)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
            .backgroundColor(PRIMARY_SOFT)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.recentPracticeCode.trim().length > 0 ? this.recentPracticeCode.slice(0, 1).toUpperCase() : '练')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY)
          }
          .width(44)
          .height(44)
          .borderRadius(14)
          .backgroundColor(PRIMARY_SOFT)
        }

        Text(this.getRecentPracticeTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(15)
          .fontColor(['#95A7C0'])
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.continueRecentPractice()
      })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(BORDER)
        .margin({ left: 58 })
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }

  /**
   * 构建句子视频识别入口。
   */
  @Builder
  private buildSentenceVideoEntry(): void {
    Column({ space: 0 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('视')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY)
        }
        .width(44)
        .height(44)
        .borderRadius(14)
        .backgroundColor(PRIMARY_SOFT)

        Column({ space: 4 }) {
          Text('句子视频识别')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)

          Text('上传短视频，查看原始识别与 AI 语义修正')
            .fontSize(12)
            .fontColor(TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(15)
          .fontColor(['#95A7C0'])
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        router.pushUrl({
          url: 'pages/SignVideoRecognitionPage'
        }).catch((err: Object) => {
          console.error(`[HomeRootTab] open sign video recognition failed: ${JSON.stringify(err)}`)
        })
      })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(BORDER)
        .margin({ left: 58 })
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }

  /**
   * 构建单个分类行。
   */
  @Builder
  private buildFeaturedCategory(item: CategoryDto): void {
    Column({ space: 0 }) {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.buildBadgeText(item))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY)
        }
        .width(40)
        .height(40)
        .borderRadius(14)
        .backgroundColor(PRIMARY_SOFT)

        Text(item.nameZh.trim().length > 0 ? item.nameZh : item.code)
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(15)
          .fontColor(['#95A7C0'])
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openCategory(item)
      })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(BORDER)
        .margin({ left: 54 })
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }

  /**
   * 构建常用分类区域。
   */
  @Builder
  private buildCategorySection(): void {
    Column({ space: 0 }) {
      Row() {
        Text('常用分类')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Blank()

        Text('查看全部')
          .fontSize(13)
          .fontColor(PRIMARY)
          .onClick(() => {
            this.onOpenTrainingTab()
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      ForEach(
        this.getFeaturedCategories(),
        (item: CategoryDto) => {
          this.buildFeaturedCategory(item)
        },
        (item: CategoryDto) => item.id.toString()
      )
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }

  /**
   * 构建状态提示。
   */
  @Builder
  private buildStateCard(title: string): void {
    Column({ space: 0 }) {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SUB)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 28, bottom: 28 })
    .backgroundColor(CARD_BG)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.buildHeroCard()
        this.buildSentenceVideoEntry()

        if (this.loading) {
          this.buildStateCard('正在加载分类')
        } else if (this.errorText.trim().length > 0) {
          this.buildStateCard('分类加载失败')
        } else {
          if (this.hasRecentPractice()) {
            this.buildContinueCard()
          }

          if (this.categories.length > 0) {
            this.buildCategorySection()
          } else {
            this.buildStateCard('当前还没有分类')
          }
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
