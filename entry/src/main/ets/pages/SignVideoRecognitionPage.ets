import photoAccessHelper from '@ohos.file.photoAccessHelper'
import { router } from '@kit.ArkUI'
import { SignVideoApi } from '../api/SignVideoApi'
import { resolveVideoFileName } from '../common/file/VideoFileReader'
import {
  SemanticCorrectionResult,
  SemanticRemovedSegment,
  SentenceSegmentResult,
  SentenceSegmentTopKItem,
  SentenceVideoRecognizeResult
} from '../model/SignVideoModels'

const PAGE_BG: string = '#FFFFFF'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#667085'
const BORDER: string = '#E5EAF3'
const SOFT_BG: string = '#F7FAFE'
const DANGER: string = '#E5484D'
const SUCCESS: string = '#16A34A'

@Entry
@Component
struct SignVideoRecognitionPage {
  @State selectedFileUri: string = ''
  @State selectedFileName: string = ''
  @State pickingVideo: boolean = false
  @State recognizing: boolean = false
  @State correcting: boolean = false
  @State errorText: string = ''
  @State hasRecognizeResult: boolean = false
  @State recognizeResult: SentenceVideoRecognizeResult = new SentenceVideoRecognizeResult()
  @State hasCorrectionResult: boolean = false
  @State correctionResult: SemanticCorrectionResult = new SemanticCorrectionResult()

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`[SignVideoRecognitionPage] back failed: ${JSON.stringify(err)}`)
    }
  }

  private async selectVideo(): Promise<void> {
    if (this.pickingVideo || this.recognizing || this.correcting) {
      return
    }

    this.pickingVideo = true
    this.errorText = ''

    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker()
      let pickerOptions = new photoAccessHelper.PhotoSelectOptions()
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
      pickerOptions.maxSelectNumber = 1
      const pickerResult = await photoPicker.select(pickerOptions)

      if (pickerResult.photoUris.length > 0) {
        const uri = pickerResult.photoUris[0].split('#')[0].split('?')[0]
        this.selectedFileUri = uri
        this.selectedFileName = resolveVideoFileName(uri)
        this.hasRecognizeResult = false
        this.hasCorrectionResult = false
        this.recognizeResult = new SentenceVideoRecognizeResult()
        this.correctionResult = new SemanticCorrectionResult()
      } else {
        this.errorText = '没有选择视频'
      }
    } catch (err) {
      this.errorText = `选择视频失败：${JSON.stringify(err)}`
    } finally {
      this.pickingVideo = false
    }
  }

  private async recognizeVideo(): Promise<void> {
    if (this.recognizing || this.correcting) {
      return
    }

    if (this.selectedFileUri.trim().length === 0) {
      this.errorText = '请先选择视频'
      return
    }

    this.recognizing = true
    this.errorText = ''
    this.hasRecognizeResult = false
    this.hasCorrectionResult = false

    try {
      this.recognizeResult = await SignVideoApi.recognizeVideo(this.selectedFileUri, this.selectedFileName)
      this.hasRecognizeResult = true
    } catch (err) {
      this.errorText = `识别失败：${JSON.stringify(err)}`
    } finally {
      this.recognizing = false
    }
  }

  private async semanticCorrect(): Promise<void> {
    if (this.correcting || this.recognizing) {
      return
    }

    if (!this.hasRecognizeResult) {
      this.errorText = '请先完成快速识别'
      return
    }

    this.correcting = true
    this.errorText = ''

    try {
      this.correctionResult = await SignVideoApi.semanticCorrect(this.recognizeResult)
      this.hasCorrectionResult = true
    } catch (err) {
      this.errorText = `AI忠实自然化失败：${JSON.stringify(err)}`
    } finally {
      this.correcting = false
    }
  }

  private getSequenceText(sequence: string[]): string {
    if (sequence.length === 0) {
      return '-'
    }
    return sequence.join(' / ')
  }

  private getFileNameText(): string {
    if (this.selectedFileName.trim().length === 0) {
      return '尚未选择视频'
    }
    return this.selectedFileName
  }

  private getRecognizeSummary(): string {
    if (!this.hasRecognizeResult) {
      return '选择视频后点击快速识别'
    }
    if (this.recognizeResult.status === 'empty') {
      return '未识别到有效词段'
    }
    return this.recognizeResult.rawTextZh.trim().length > 0 ? this.recognizeResult.rawTextZh : '暂无中文展示'
  }

  private formatScore(value: number): string {
    if (!Number.isFinite(value) || value <= 0) {
      return '0.00'
    }
    return value.toFixed(2)
  }

  private buildTopKText(items: SentenceSegmentTopKItem[]): string {
    if (items.length === 0) {
      return '暂无候选'
    }

    const texts: string[] = []
    items.forEach((item: SentenceSegmentTopKItem) => {
      const display = item.labelZh.trim().length > 0 ? item.labelZh : item.label
      texts.push(`${display}(${this.formatScore(item.avgProb)}, hit=${item.hitCount})`)
    })
    return texts.join('，')
  }

  private getCorrectedGlossText(): string {
    if (this.correctionResult.correctedGlossSequence.length > 0) {
      return this.getSequenceText(this.correctionResult.correctedGlossSequence)
    }
    return this.getSequenceText(this.correctionResult.correctedSequence)
  }

  private getChineseTranslationText(): string {
    if (this.correctionResult.chineseTranslation.trim().length > 0) {
      return this.correctionResult.chineseTranslation
    }
    if (this.correctionResult.correctedTextZh.trim().length > 0) {
      return this.correctionResult.correctedTextZh
    }
    return '-'
  }

  private getEnglishSentenceText(): string {
    if (this.correctionResult.englishSentence.trim().length > 0) {
      return this.correctionResult.englishSentence
    }
    return '-'
  }

  private getTranslationNoteText(): string {
    if (this.correctionResult.translationNote.trim().length > 0) {
      return this.correctionResult.translationNote
    }
    if (this.correctionResult.reasonZh.trim().length > 0) {
      return this.correctionResult.reasonZh
    }
    if (this.correctionResult.reason.trim().length > 0) {
      return this.correctionResult.reason
    }
    return 'AI候选排序与自然化暂不可用，已保留原始识别结果。'
  }

  private getCorrectionBadgeText(): string {
    if (this.correctionResult.fallback) {
      return 'fallback'
    }
    if (this.correctionResult.isIncomplete || this.correctionResult.translationConfidence === 'low') {
      return '低置信'
    }
    if (this.correctionResult.correctionApplied) {
      return '已选候选'
    }
    return '保持原样'
  }

  private getCorrectionBadgeColor(): string {
    if (this.correctionResult.fallback ||
      this.correctionResult.isIncomplete ||
      this.correctionResult.translationConfidence === 'low') {
      return DANGER
    }
    return SUCCESS
  }

  private getCorrectionBadgeBg(): string {
    if (this.correctionResult.fallback ||
      this.correctionResult.isIncomplete ||
      this.correctionResult.translationConfidence === 'low') {
      return '#FFF1F2'
    }
    return '#ECFDF3'
  }

  private isErrorText(text: string): boolean {
    return text.indexOf('失败') >= 0 ||
      text.indexOf('请先') >= 0 ||
      text.indexOf('没有选择') >= 0
  }

  @Builder
  private buildTopBar(): void {
    Row({ space: 10 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([TEXT_SUB])
      }
      .width(40)
      .height(40)
      .borderRadius(18)
      .backgroundColor(Color.Transparent)
      .stateEffect(false)
      .onClick(() => {
        this.goBack()
      })

      Text('句子视频识别')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Blank()
    }
    .width('100%')
    .padding({ top: 2, bottom: 8 })
  }

  @Builder
  private buildIntroCard(): void {
    Column({ space: 8 }) {
      Text('上传一段手语短视频，系统会先返回视觉模型原始识别结果；你也可以继续使用 AI 候选排序，把合法候选 gloss 忠实自然化为中英文表达。')
        .fontSize(14)
        .fontColor(TEXT_SUB)
        .lineHeight(22)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(18)
    .backgroundColor(PRIMARY_SOFT)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildVideoSelectCard(): void {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
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
          Text('选择视频')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)

          Text(this.getFileNameText())
            .fontSize(12)
            .fontColor(TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(this.pickingVideo ? '打开中...' : '选择')
          .height(38)
          .fontSize(14)
          .fontColor(PRIMARY)
          .backgroundColor(SOFT_BG)
          .borderRadius(14)
          .border({ width: 1, color: BORDER })
          .enabled(!this.pickingVideo && !this.recognizing && !this.correcting)
          .onClick(() => {
            void this.selectVideo()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Button(this.recognizing ? '识别中...' : '快速识别')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(PRIMARY)
          .borderRadius(16)
          .enabled(!this.recognizing && !this.correcting && this.selectedFileUri.trim().length > 0)
          .onClick(() => {
            void this.recognizeVideo()
          })

        Button(this.correcting ? '自然化中...' : 'AI忠实自然化')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasRecognizeResult ? PRIMARY : TEXT_SUB)
          .backgroundColor(SOFT_BG)
          .borderRadius(16)
          .border({ width: 1, color: BORDER })
          .enabled(!this.correcting && !this.recognizing && this.hasRecognizeResult)
          .onClick(() => {
            void this.semanticCorrect()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(18)
    .backgroundColor(CARD_BG)
    .border({ width: 1, color: BORDER })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTipCard(): void {
    if (this.errorText.trim().length > 0) {
      Text(this.errorText)
        .width('100%')
        .fontSize(13)
        .fontColor(this.isErrorText(this.errorText) ? DANGER : TEXT_SUB)
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .borderRadius(14)
        .backgroundColor('#FFF7F7')
    }
  }

  @Builder
  private buildRecognizeResultCard(): void {
    Column({ space: 12 }) {
      Text('原始识别结果')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Text(`中文：${this.getRecognizeSummary()}`)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .lineHeight(22)

      Text(`Gloss：${this.getSequenceText(this.recognizeResult.rawSequence)}`)
        .fontSize(13)
        .fontColor(TEXT_SUB)
        .lineHeight(20)

      Row({ space: 12 }) {
        Text(`状态：${this.recognizeResult.status}`)
          .fontSize(12)
          .fontColor(TEXT_SUB)

        Text(`耗时：${this.recognizeResult.elapsedMs} ms`)
          .fontSize(12)
          .fontColor(TEXT_SUB)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(18)
    .backgroundColor(CARD_BG)
    .border({ width: 1, color: BORDER })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSegmentItem(item: SentenceSegmentResult): void {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        Text(`${item.segmentIndex}. ${item.rawLabel}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)

        Text(item.rawLabelZh)
          .fontSize(13)
          .fontColor(PRIMARY)

        Blank()
      }
      .width('100%')

      Text(`avg=${this.formatScore(item.avgConfidence)}  max=${this.formatScore(item.maxConfidence)}  frames=${item.startFrame}-${item.endFrame}`)
        .fontSize(12)
        .fontColor(TEXT_SUB)

      Text(`TopK：${this.buildTopKText(item.topK)}`)
        .fontSize(12)
        .fontColor(TEXT_SUB)
        .lineHeight(18)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  private buildSegmentCard(): void {
    Column({ space: 0 }) {
      Text('词段详情')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .padding({ bottom: 8 })

      if (this.recognizeResult.segmentTopK.length === 0) {
        Text('暂无词段详情')
          .width('100%')
          .fontSize(13)
          .fontColor(TEXT_SUB)
          .padding({ top: 14, bottom: 14 })
      } else {
        ForEach(
          this.recognizeResult.segmentTopK,
          (item: SentenceSegmentResult) => {
            this.buildSegmentItem(item)
          },
          (item: SentenceSegmentResult) => item.segmentIndex.toString()
        )
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 8 })
    .borderRadius(18)
    .backgroundColor(CARD_BG)
    .border({ width: 1, color: BORDER })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildCorrectionCard(): void {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('AI候选排序与自然化')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Text(this.getCorrectionBadgeText())
          .fontSize(12)
          .fontColor(this.getCorrectionBadgeColor())
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
          .backgroundColor(this.getCorrectionBadgeBg())

        Blank()
      }
      .width('100%')

      Text(`中文自然表达：${this.getChineseTranslationText()}`)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .lineHeight(22)

      Text(`英文自然表达：${this.getEnglishSentenceText()}`)
        .fontSize(13)
        .fontColor(TEXT_SUB)
        .lineHeight(20)

      Text(`候选Gloss：${this.getCorrectedGlossText()}`)
        .fontSize(13)
        .fontColor(TEXT_SUB)
        .lineHeight(20)

      Row({ space: 10 }) {
        Text(`候选：${this.correctionResult.selectedCandidateId.trim().length > 0 ? this.correctionResult.selectedCandidateId : '-'}`)
          .fontSize(12)
          .fontColor(TEXT_SUB)

        Text(`置信：${this.correctionResult.translationConfidence.trim().length > 0 ? this.correctionResult.translationConfidence : '-'}`)
          .fontSize(12)
          .fontColor(TEXT_SUB)
      }
      .width('100%')

      if (this.correctionResult.isIncomplete || this.correctionResult.translationConfidence === 'low') {
        Text('识别结果可能不完整，请重新录制或放慢动作。')
          .width('100%')
          .fontSize(13)
          .fontColor(DANGER)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .borderRadius(12)
          .backgroundColor('#FFF7F7')
      }

      Text(this.getTranslationNoteText())
        .fontSize(13)
        .fontColor(TEXT_SUB)
        .lineHeight(20)

      if (this.correctionResult.removedSegments.length > 0) {
        Column({ space: 8 }) {
          Text('被删除词段')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)

          ForEach(
            this.correctionResult.removedSegments,
            (item: SemanticRemovedSegment) => {
              this.buildRemovedSegment(item)
            },
            (item: SemanticRemovedSegment) => `${item.segmentIndex}-${item.rawLabel}`
          )
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(18)
    .backgroundColor(CARD_BG)
    .border({ width: 1, color: BORDER })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildRemovedSegment(item: SemanticRemovedSegment): void {
    Column({ space: 4 }) {
      Text(`${item.rawLabelZh.trim().length > 0 ? item.rawLabelZh : item.rawLabel} / ${item.rawLabel}`)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)

      Text(item.reasonZh.trim().length > 0 ? item.reasonZh : item.reason)
        .fontSize(12)
        .fontColor(TEXT_SUB)
        .lineHeight(18)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor(SOFT_BG)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 10 }) {
      this.buildTopBar()

      Scroll() {
        Column({ space: 14 }) {
          this.buildIntroCard()
          this.buildVideoSelectCard()
          this.buildTipCard()

          if (this.hasRecognizeResult) {
            this.buildRecognizeResultCard()
            this.buildSegmentCard()
          }

          if (this.hasCorrectionResult) {
            this.buildCorrectionCard()
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 0, right: 0, top: 0, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(PAGE_BG)
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 0 })
    .backgroundColor(PAGE_BG)
    .alignItems(HorizontalAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
