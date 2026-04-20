import { router } from '@kit.ArkUI'
import { GesturePracticePageParams } from '../model/GestureModels'

@Entry
@Component
struct GesturePracticePage {
  @State gestureId: number = 0
  @State chineseName: string = ''
  @State label: string = ''

  @State predictedLabel: string = '--'
  @State confidence: number = 0
  @State stableHitCount: number = 0
  @State statusText: string = '尚未开始识别'
  @State isRecognizing: boolean = false

  aboutToAppear(): void {
    this.readParams()
  }

  private readParams(): void {
    try {
      let params = router.getParams() as GesturePracticePageParams
      if (params) {
        this.gestureId = Number(params.gestureId)
        this.chineseName = String(params.chineseName)
        this.label = String(params.label)
      }
    } catch (err) {
      console.error(`读取训练页参数失败：${JSON.stringify(err)}`)
    }
  }

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回手势列表页失败：${JSON.stringify(err)}`)
    }
  }

  private startMockRecognize(): void {
    this.isRecognizing = true
    this.statusText = '识别中'
    this.predictedLabel = '--'
    this.confidence = 0
    this.stableHitCount = 0
  }

  private stopMockRecognize(): void {
    this.isRecognizing = false
    this.statusText = '已停止识别'
    this.predictedLabel = '--'
    this.confidence = 0
    this.stableHitCount = 0
  }

  private mockUnknown(): void {
    this.isRecognizing = true
    this.predictedLabel = '--'
    this.confidence = 0.42
    this.stableHitCount = 0
    this.statusText = '未稳定识别，请调整动作'
  }

  private mockWrong(): void {
    this.isRecognizing = true
    this.predictedLabel = 'call'
    this.confidence = 0.89
    this.stableHitCount = 0
    this.statusText = '动作不匹配'
  }

  private mockCorrect(): void {
    this.isRecognizing = true
    this.predictedLabel = this.label
    this.confidence = 0.93
    this.stableHitCount = 3
    this.statusText = '动作正确'
  }

  private getStatusColor(): string {
    if (this.statusText === '动作正确') {
      return '#18A058'
    }
    if (this.statusText === '动作不匹配') {
      return '#D03050'
    }
    if (this.statusText === '未稳定识别，请调整动作') {
      return '#F0A020'
    }
    return '#666666'
  }

  private getVideoPlaceholderText(): string {
    if (this.isRecognizing) {
      return '视频预览区域（后续接真实识别）'
    }
    return '点击“开始识别”后，这里接入视频预览'
  }

  @Builder
  private buildTopBar(): void {
    Row() {
      Button('返回')
        .fontSize(16)
        .height(40)
        .onClick(() => {
          this.goBack()
        })

      Text('手势训练')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  build() {
    Column() {
      this.buildTopBar()

      Scroll() {
        Column({ space: 16 }) {
          // 当前手势信息
          Column({ space: 8 }) {
            Text(`当前手势：${this.chineseName}`)
              .fontSize(24)
              .fontWeight(FontWeight.Medium)

            Text(`模型标签：${this.label}`)
              .fontSize(16)
              .fontColor('#666666')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F7F8FA')
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)

          // 视频预览区
          Column({ space: 10 }) {
            Text('视频预览')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)

            Text(this.isRecognizing ? '识别状态：运行中' : '识别状态：未启动')
              .fontSize(14)
              .fontColor('#999999')

            Column() {
              Text(this.getVideoPlaceholderText())
                .fontSize(16)
                .fontColor('#666666')
            }
            .width('72%')
            .aspectRatio(9 / 16)
            .backgroundColor('#F1F3F5')
            .borderRadius(20)
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F7F8FA')
          .borderRadius(16)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Start)

          // 识别结果区
          Column({ space: 10 }) {
            Text('识别结果')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)

            Text(`当前识别标签：${this.predictedLabel}`)
              .fontSize(16)

            Text(`当前置信度：${this.confidence.toFixed(2)}`)
              .fontSize(16)

            Text(`连续命中帧数：${this.stableHitCount}`)
              .fontSize(16)

            Text(`当前状态：${this.statusText}`)
              .fontSize(16)
              .fontColor(this.getStatusColor())
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F7F8FA')
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)

          // 控制区
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Button('开始识别')
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.startMockRecognize()
                })

              Button('停止识别')
                .layoutWeight(1)
                .height(44)
                .onClick(() => {
                  this.stopMockRecognize()
                })
            }

            Row({ space: 12 }) {
              Button('模拟未识别')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .onClick(() => {
                  this.mockUnknown()
                })

              Button('模拟错误')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .onClick(() => {
                  this.mockWrong()
                })

              Button('模拟正确')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .onClick(() => {
                  this.mockCorrect()
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F7F8FA')
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}