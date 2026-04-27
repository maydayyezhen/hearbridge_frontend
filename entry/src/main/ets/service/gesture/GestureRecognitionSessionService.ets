import { GestureWsApi } from '../../api/GestureWsApi'
import { GestureWsResultMessage } from '../../model/GestureWsModels'

/**
 * 手势识别会话状态快照。
 */
export interface GestureRecognitionSessionState {
  /** 当前识别状态文案。 */
  recognitionStatusText: string

  /** 当前是否正在识别。 */
  isRecognizing: boolean

  /** 当前动作是否已经识别成功。 */
  hasRecognitionSucceeded: boolean

  /** 当前实时识别服务使用的模型版本名称。 */
  recognitionModelVersionName: string

  /** 当前实时识别是否使用管理端发布模型。 */
  recognitionUsingPublishedModel: boolean
}

/**
 * 手势识别会话启动参数。
 */
export interface GestureRecognitionStartOptions {
  /** 当前是否存在 dataset 采集占用。 */
  isDatasetBusy: boolean

  /** 相机预览是否已经启动。 */
  previewStarted: boolean

  /** 当前是否有可用 Surface。 */
  hasSurface: boolean

  /** 当前手势资源编码。 */
  resourceCode: string

  /** 当前帧宽度。 */
  frameWidth: number

  /** 当前帧高度。 */
  frameHeight: number

  /** 识别启动时的首帧 JPEG。 */
  firstFrame: ArrayBuffer | null
}

/**
 * 手势识别状态更新回调。
 */
type GestureRecognitionStateCallback = (state: GestureRecognitionSessionState) => void

/**
 * 手势识别停止回调。
 */
type GestureRecognitionStopCallback = () => void

/**
 * 手势实时识别会话服务。
 *
 * 职责：
 * 1. 管理 GestureWsApi 连接；
 * 2. 管理识别会话 start / stop；
 * 3. 管理识别链路最新帧发送；
 * 4. 处理识别结果并向页面同步状态。
 *
 * 注意：
 * 该服务不负责相机、抓帧、PixelMap 处理和 UI 展示。
 */
export class GestureRecognitionSessionService {
  /** 手势识别 WebSocket API。 */
  private gestureWsApi: GestureWsApi = new GestureWsApi()

  /** 识别链路待发送的最新帧。 */
  private pendingFrame: ArrayBuffer | null = null

  /** 识别链路当前是否正在发送帧。 */
  private isFrameSending: boolean = false

  /** 上报给识别服务的帧率。 */
  private readonly gestureFrameFps: number = 10

  /** 当前识别状态文案。 */
  private recognitionStatusText: string = '点击开始识别'

  /** 当前是否正在识别。 */
  private isRecognizing: boolean = false

  /** 当前动作是否已经识别成功。 */
  private hasRecognitionSucceeded: boolean = false

  /** 当前实时识别服务使用的模型版本名称。 */
  private recognitionModelVersionName: string = '尚未建立识别会话'

  /** 当前实时识别是否使用管理端发布模型。 */
  private recognitionUsingPublishedModel: boolean = false

  /** 当前目标手势编码。 */
  private targetResourceCode: string = ''

  /** 状态更新回调。 */
  private onStateChange: GestureRecognitionStateCallback | null = null

  /** 识别停止回调。 */
  private onSessionStopped: GestureRecognitionStopCallback | null = null

  /**
   * 设置状态更新回调。
   *
   * @param callback 状态更新回调
   */
  setOnStateChange(callback: GestureRecognitionStateCallback): void {
    this.onStateChange = callback
    this.emitState()
  }

  /**
   * 设置识别停止回调。
   *
   * @param callback 识别停止回调
   */
  setOnSessionStopped(callback: GestureRecognitionStopCallback): void {
    this.onSessionStopped = callback
  }

  /**
   * 当前是否允许接收抓帧结果。
   *
   * @returns 是否允许接收抓帧结果
   */
  canAcceptFrame(): boolean {
    return this.isRecognizing && !this.hasRecognitionSucceeded
  }

  /**
   * 启动手势实时识别。
   *
   * @param options 启动参数
   * @returns 是否成功启动识别
   */
  async start(options: GestureRecognitionStartOptions): Promise<boolean> {
    if (this.isRecognizing) {
      return false
    }

    if (options.isDatasetBusy) {
      this.recognitionStatusText = '正在采集或等待保存样本，请先处理当前样本'
      this.emitState()
      return false
    }

    if (!options.previewStarted || !options.hasSurface) {
      this.recognitionStatusText = '预览尚未就绪'
      this.emitState()
      return false
    }

    if (options.firstFrame === null || options.frameWidth <= 0 || options.frameHeight <= 0) {
      this.isRecognizing = false
      this.recognitionStatusText = '首帧抓取失败'
      this.emitState()
      return false
    }

    this.targetResourceCode = options.resourceCode
    this.resetRecognitionView()
    this.isRecognizing = true
    this.recognitionStatusText = '请露出双肩，并将手势保持在画面内（0/30）'
    this.emitState()

    const connected = await this.gestureWsApi.connect(
      (result: GestureWsResultMessage) => {
        this.handleGestureWsResult(result)
      },
      (_message: string) => {
        this.recognitionStatusText = '识别服务异常'
        this.emitState()
      },
      () => {
        this.isRecognizing = false
        if (!this.hasRecognitionSucceeded) {
          this.recognitionStatusText = '识别已停止'
        }
        this.clearFrameState()
        this.emitState()
        this.emitStopped()
      }
    )

    if (!connected) {
      this.isRecognizing = false
      this.recognitionStatusText = '识别服务连接失败'
      this.emitState()
      return false
    }

    const started = await this.gestureWsApi.startSession(
      options.frameWidth,
      options.frameHeight,
      this.gestureFrameFps,
    )

    if (!started) {
      this.isRecognizing = false
      this.recognitionStatusText = '识别服务启动失败'
      this.emitState()
      await this.gestureWsApi.disconnect()
      return false
    }

    this.enqueueFrame(options.firstFrame)
    return true
  }

  /**
   * 停止手势实时识别。
   *
   * @param preserveStatus 是否保留当前识别状态文案
   */
  async stop(preserveStatus: boolean = false): Promise<void> {
    this.isRecognizing = false
    this.clearFrameState()

    if (!preserveStatus) {
      this.resetRecognitionView()
    }

    this.emitState()
    await this.gestureWsApi.disconnect()
  }

  /**
   * 断开识别服务。
   */
  async disconnect(): Promise<void> {
    this.isRecognizing = false
    this.clearFrameState()
    await this.gestureWsApi.disconnect()
    this.emitState()
  }

  /**
   * 将识别链路的最新帧放入待发送槽位。
   *
   * @param frame JPEG 帧
   */
  enqueueFrame(frame: ArrayBuffer): void {
    this.pendingFrame = frame
    void this.flushPendingFrame()
  }

  /**
   * 发送识别链路中最新的一帧。
   */
  private async flushPendingFrame(): Promise<void> {
    if (this.isFrameSending || this.pendingFrame === null) {
      return
    }

    if (!this.isRecognizing || this.hasRecognitionSucceeded) {
      return
    }

    if (!this.gestureWsApi.isConnected() || !this.gestureWsApi.isStarted()) {
      return
    }

    const frame = this.pendingFrame
    this.pendingFrame = null
    this.isFrameSending = true

    try {
      await this.gestureWsApi.sendFrame(frame)
    } finally {
      this.isFrameSending = false

      if (this.pendingFrame !== null) {
        void this.flushPendingFrame()
      }
    }
  }

  /**
   * 处理识别成功。
   */
  private async handleRecognitionSuccess(): Promise<void> {
    if (this.hasRecognitionSucceeded) {
      return
    }

    this.hasRecognitionSucceeded = true
    this.recognitionStatusText = '识别成功'
    this.emitState()
    await this.stop(true)
    this.emitStopped()
  }

  /**
   * 处理识别服务结果。
   *
   * @param result 识别结果
   */
  private handleGestureWsResult(result: GestureWsResultMessage): void {
    if (this.hasRecognitionSucceeded) {
      return
    }

    this.recognitionModelVersionName =
      result.modelVersionName && result.modelVersionName.length > 0
        ? result.modelVersionName
        : 'default'

    this.recognitionUsingPublishedModel = result.usingPublishedModel

    if (result.status === 'no_hand' || result.status === 'missing_hand') {
      this.recognitionStatusText = '未检测到有效动作，请露出双肩并将手势放入画面内'
      this.emitState()
      return
    }

    if (result.status === 'warming_up') {
      const safeTotal = result.windowSize > 0 ? result.windowSize : 30
      const safeProgress = Math.max(0, Math.min(result.validFrames, safeTotal))
      this.recognitionStatusText = `请保持上半身和手势在画面内（${safeProgress}/${safeTotal}）`
      this.emitState()
      return
    }

    if (result.status === 'predicted') {
      const recognizedLabel = result.label && result.label.length > 0 ? result.label : '未知动作'
      if (result.label === this.targetResourceCode) {
        void this.handleRecognitionSuccess()
      } else {
        this.recognitionStatusText = `当前识别为“${recognizedLabel}”，请调整动作后重试`
        this.emitState()
      }
      return
    }

    this.recognitionStatusText = '等待识别结果'
    this.emitState()
  }

  /**
   * 重置识别展示状态。
   */
  private resetRecognitionView(): void {
    this.recognitionStatusText = '请露出双肩，并让手势动作保持在画面内'
    this.hasRecognitionSucceeded = false
    this.recognitionModelVersionName = '尚未建立识别会话'
    this.recognitionUsingPublishedModel = false
  }

  /**
   * 清空帧发送状态。
   */
  private clearFrameState(): void {
    this.pendingFrame = null
    this.isFrameSending = false
  }

  /**
   * 向页面同步识别状态。
   */
  private emitState(): void {
    if (this.onStateChange === null) {
      return
    }

    this.onStateChange({
      recognitionStatusText: this.recognitionStatusText,
      isRecognizing: this.isRecognizing,
      hasRecognitionSucceeded: this.hasRecognitionSucceeded,
      recognitionModelVersionName: this.recognitionModelVersionName,
      recognitionUsingPublishedModel: this.recognitionUsingPublishedModel
    })
  }

  /**
   * 通知页面识别会话已经停止。
   */
  private emitStopped(): void {
    if (this.onSessionStopped !== null) {
      this.onSessionStopped()
    }
  }
}
