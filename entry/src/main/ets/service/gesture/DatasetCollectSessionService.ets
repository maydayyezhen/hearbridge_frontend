import { DatasetWsApi } from '../../api/DatasetWsApi'
import { DatasetWsStatusMessage } from '../../model/DatasetWsModels'

/**
 * raw dataset 采集状态快照。
 */
export interface DatasetCollectSessionState {
  /** 采集状态文案。 */
  datasetStatusText: string

  /** 当前是否正在采集。 */
  isDatasetCollecting: boolean

  /** 当前有效帧数量。 */
  datasetValidFrames: number

  /** 当前窗口帧数。 */
  datasetWindowSize: number

  /** 采集倒计时文案。 */
  datasetCountdownText: string

  /** 是否等待用户确认保存样本。 */
  isDatasetWaitingConfirm: boolean
}

/**
 * raw dataset 采集启动参数。
 */
export interface DatasetCollectStartOptions {
  /** 是否启用开发者采集模式。 */
  enableDatasetCollect: boolean

  /** 当前是否正在识别。 */
  isRecognizing: boolean

  /** 相机预览是否已启动。 */
  previewStarted: boolean

  /** 当前是否有可用 Surface。 */
  hasSurface: boolean

  /** 当前手势资源编码。 */
  resourceCode: string
}

/**
 * raw dataset 采集状态更新回调。
 */
type DatasetCollectStateCallback = (state: DatasetCollectSessionState) => void

/**
 * raw dataset 采集会话服务。
 *
 * 职责：
 * 1. 管理 DatasetWsApi 连接；
 * 2. 管理采集倒计时；
 * 3. 管理待发送最新帧；
 * 4. 管理保存 / 丢弃 / 取消状态；
 * 5. 向页面回传 UI 状态。
 *
 * 注意：
 * 该服务不负责相机、抓帧和 UI 展示。
 */
export class DatasetCollectSessionService {
  /** raw dataset 采集 WebSocket API。 */
  private datasetWsApi: DatasetWsApi = new DatasetWsApi()

  /** 采集链路待发送的最新帧。 */
  private pendingDatasetFrame: ArrayBuffer | null = null

  /** 采集链路当前是否正在发送帧。 */
  private isDatasetFrameSending: boolean = false

  /** raw dataset 采集帧率。 */
  private readonly datasetFrameFps: number = 10

  /** raw dataset 单个样本窗口大小。 */
  private readonly datasetWindowFrameCount: number = 30

  /** 点击采集后给用户准备动作的倒计时秒数。 */
  private readonly datasetPrepareSeconds: number = 3

  /** raw dataset 采集倒计时开始时间戳。 */
  private datasetPrepareStartTime: number = 0

  /** 采集状态文案。 */
  private datasetStatusText: string = '可在查看数字人后采集当前动作样本'

  /** 当前是否正在采集。 */
  private isDatasetCollecting: boolean = false

  /** 当前有效帧数量。 */
  private datasetValidFrames: number = 0

  /** 当前窗口帧数。 */
  private datasetWindowSize: number = 30

  /** 采集倒计时文案。 */
  private datasetCountdownText: string = ''

  /** 是否等待用户确认保存样本。 */
  private isDatasetWaitingConfirm: boolean = false

  /** 状态更新回调。 */
  private onStateChange: DatasetCollectStateCallback | null = null

  /**
   * 设置状态更新回调。
   *
   * @param callback 状态更新回调
   */
  setOnStateChange(callback: DatasetCollectStateCallback): void {
    this.onStateChange = callback
    this.emitState()
  }

  /**
   * 当前是否允许接收抓帧结果。
   *
   * @returns 是否允许接收抓帧结果
   */
  canAcceptFrame(): boolean {
    return this.isDatasetCollecting && !this.isDatasetWaitingConfirm
  }

  /**
   * 启动 raw dataset 采集。
   *
   * @param options 启动参数
   * @returns 是否成功启动采集
   */
  async start(options: DatasetCollectStartOptions): Promise<boolean> {
    if (!options.enableDatasetCollect) {
      this.datasetStatusText = '开发者采集模式未开启，普通用户不能采集 raw dataset 样本'
      this.emitState()
      return false
    }

    if (this.isDatasetCollecting) {
      return false
    }

    if (options.isRecognizing) {
      this.datasetStatusText = '请先停止识别，再采集样本'
      this.emitState()
      return false
    }

    if (!options.previewStarted || !options.hasSurface) {
      this.datasetStatusText = '相机预览尚未就绪'
      this.emitState()
      return false
    }

    if (options.resourceCode === '') {
      this.datasetStatusText = '当前动作编码为空，无法采集'
      this.emitState()
      return false
    }

    this.datasetValidFrames = 0
    this.datasetWindowSize = this.datasetWindowFrameCount
    this.datasetCountdownText = ''
    this.isDatasetWaitingConfirm = false
    this.datasetPrepareStartTime = Date.now()
    this.isDatasetCollecting = true
    this.datasetStatusText = `准备采集当前动作：${options.resourceCode}`
    this.emitState()

    const connected = await this.datasetWsApi.connect(
      (message: DatasetWsStatusMessage) => {
        this.handleDatasetStatus(message)
      },
      (message: string) => {
        this.datasetStatusText = message
        this.emitState()
      },
      () => {
        this.isDatasetCollecting = false
        this.datasetCountdownText = ''
        this.datasetStatusText = '采集连接已关闭'
        this.emitState()
      }
    )

    if (!connected) {
      this.isDatasetCollecting = false
      this.datasetStatusText = '连接采集服务失败'
      this.emitState()
      return false
    }

    const started = await this.datasetWsApi.startDataset(
      options.resourceCode,
      this.datasetFrameFps,
      this.datasetWindowFrameCount
    )

    if (!started) {
      this.isDatasetCollecting = false
      this.datasetStatusText = '启动采集失败'
      this.emitState()
      await this.datasetWsApi.disconnect()
      return false
    }

    return true
  }

  /**
   * 将最新帧放入待发送槽位。
   *
   * @param frame JPEG 帧
   */
  enqueueFrame(frame: ArrayBuffer): void {
    this.pendingDatasetFrame = frame
    void this.flushPendingFrame()
  }

  /**
   * 停止采集。
   *
   * @param preserveStatus 是否保留当前状态文案
   */
  async stop(preserveStatus: boolean = false): Promise<void> {
    const wasCollecting = this.isDatasetCollecting
    const wasWaitingConfirm = this.isDatasetWaitingConfirm

    this.isDatasetCollecting = false
    this.isDatasetWaitingConfirm = false
    this.datasetCountdownText = ''
    this.pendingDatasetFrame = null
    this.isDatasetFrameSending = false

    if (wasCollecting || wasWaitingConfirm) {
      await this.datasetWsApi.cancelDataset()
    }

    await this.datasetWsApi.disconnect()

    if (!preserveStatus) {
      this.datasetStatusText = wasWaitingConfirm ? '待确认样本已取消' : '采集已取消'
      this.datasetValidFrames = 0
    }

    this.emitState()
  }

  /**
   * 确认保存当前待确认样本。
   */
  async confirmSave(): Promise<void> {
    if (!this.isDatasetWaitingConfirm) {
      return
    }

    const success = await this.datasetWsApi.saveDataset()
    if (!success) {
      this.datasetStatusText = '确认保存失败：采集服务未连接'
      this.emitState()
    }
  }

  /**
   * 丢弃当前待确认样本。
   */
  async discardPending(): Promise<void> {
    if (!this.isDatasetWaitingConfirm) {
      return
    }

    const success = await this.datasetWsApi.discardDataset()
    if (!success) {
      this.isDatasetWaitingConfirm = false
      this.datasetValidFrames = 0
      this.datasetStatusText = '丢弃失败：采集服务未连接，已在前端清空状态'
      await this.datasetWsApi.disconnect()
      this.emitState()
    }
  }

  /**
   * 断开采集服务。
   */
  async disconnect(): Promise<void> {
    this.isDatasetCollecting = false
    this.isDatasetWaitingConfirm = false
    this.datasetCountdownText = ''
    this.pendingDatasetFrame = null
    this.isDatasetFrameSending = false
    await this.datasetWsApi.disconnect()
    this.emitState()
  }

  /**
   * 发送待处理的最新帧。
   */
  private async flushPendingFrame(): Promise<void> {
    if (this.isDatasetFrameSending || this.pendingDatasetFrame === null) {
      return
    }

    if (!this.isDatasetCollecting || this.isDatasetWaitingConfirm) {
      this.pendingDatasetFrame = null
      return
    }

    const frame = this.pendingDatasetFrame
    this.pendingDatasetFrame = null
    this.isDatasetFrameSending = true

    try {
      await this.handleDatasetFrame(frame)
    } finally {
      this.isDatasetFrameSending = false

      if (this.pendingDatasetFrame !== null) {
        void this.flushPendingFrame()
      }
    }
  }

  /**
   * 处理单帧采集发送。
   *
   * @param jpegBytes JPEG 帧
   */
  private async handleDatasetFrame(jpegBytes: ArrayBuffer): Promise<void> {
    if (!this.isDatasetCollecting || this.isDatasetWaitingConfirm) {
      return
    }

    const elapsedMs = Date.now() - this.datasetPrepareStartTime
    const remainingMs = this.datasetPrepareSeconds * 1000 - elapsedMs

    if (remainingMs > 0) {
      const remainingSecond = Math.ceil(remainingMs / 1000)
      this.datasetCountdownText = `${remainingSecond}`
      this.datasetStatusText = `准备采集：${remainingSecond} 秒后开始`
      this.emitState()
      return
    }

    this.datasetCountdownText = ''
    this.emitState()

    if (!this.datasetWsApi.isConnected()) {
      return
    }

    await this.datasetWsApi.sendFrame(jpegBytes)
  }

  /**
   * 处理采集服务状态消息。
   *
   * @param message 采集服务状态消息
   */
  private handleDatasetStatus(message: DatasetWsStatusMessage): void {
    this.datasetValidFrames = message.validFrames
    this.datasetWindowSize = message.windowSize > 0 ? message.windowSize : this.datasetWindowFrameCount

    if (message.status === 'ready') {
      this.datasetStatusText = '采集服务已就绪，请摆好动作'
      this.emitState()
      return
    }

    if (message.status === 'invalid_frame') {
      this.datasetStatusText = message.message.length > 0 ? message.message : '无效帧：请露出双肩和手部'
      this.emitState()
      return
    }

    if (message.status === 'collecting') {
      this.datasetStatusText = `采集中：${this.datasetValidFrames}/${this.datasetWindowSize}`
      this.emitState()
      return
    }

    if (message.status === 'ready_to_save') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = true
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetValidFrames = this.datasetWindowSize
      this.datasetStatusText = message.message.length > 0 ? message.message : '样本采集完成，请确认是否保存'
      this.emitState()
      return
    }

    if (message.status === 'saved') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = false
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetValidFrames = this.datasetWindowSize
      this.datasetStatusText = `采集保存成功：${message.label}`
      this.emitState()
      void this.datasetWsApi.disconnect()
      return
    }

    if (message.status === 'discarded') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = false
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetValidFrames = 0
      this.datasetStatusText = '样本已丢弃，可重新采集'
      this.emitState()
      void this.datasetWsApi.disconnect()
      return
    }

    if (message.status === 'cancelled') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = false
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetStatusText = '采集已取消'
      this.emitState()
      return
    }
  }

  /**
   * 向页面同步采集状态。
   */
  private emitState(): void {
    if (this.onStateChange === null) {
      return
    }

    this.onStateChange({
      datasetStatusText: this.datasetStatusText,
      isDatasetCollecting: this.isDatasetCollecting,
      datasetValidFrames: this.datasetValidFrames,
      datasetWindowSize: this.datasetWindowSize,
      datasetCountdownText: this.datasetCountdownText,
      isDatasetWaitingConfirm: this.isDatasetWaitingConfirm
    })
  }
}
