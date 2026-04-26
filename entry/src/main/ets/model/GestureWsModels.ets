/**
 * 手势识别 WebSocket start 消息
 */
export class GestureWsStartMessage {
  type: string
  format: string
  width: number
  height: number
  fps: number

  constructor(width: number, height: number, fps: number) {
    this.type = 'start'
    this.format = 'jpeg'
    this.width = width
    this.height = height
    this.fps = fps
  }
}

/**
 * 手势识别服务返回的 result 消息
 */
export interface GestureWsResultMessage {
  /** 消息类型。 */
  type: string

  /** 当前识别状态。 */
  status: string

  /** 当前识别标签。 */
  label: string

  /** 识别置信度。 */
  confidence: number

  /** 有效帧数量。 */
  validFrames: number

  /** 窗口大小。 */
  windowSize: number

  /** 是否检测到有效手部。 */
  hasValidHand: boolean

  /** 调试用关键点。 */
  landmarks?: Array<Array<Array<number>>>

  /** 当前识别会话使用的模型版本名称。 */
  modelVersionName: string

  /** 当前识别会话使用的模型文件路径。 */
  modelPath: string

  /** 当前识别会话使用的标签映射文件路径。 */
  labelMapPath: string

  /** 是否使用管理端发布的模型。 */
  usingPublishedModel: boolean
}