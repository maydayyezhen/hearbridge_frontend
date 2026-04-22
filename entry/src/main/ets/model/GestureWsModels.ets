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
  type: string
  status: string
  label: string
  confidence: number
  validFrames: number
  windowSize: number
  hasValidHand: boolean
  landmarks?: Array<Array<Array<number>>>
}