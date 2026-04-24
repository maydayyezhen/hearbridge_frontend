/**
 * 本地手部关键点（原始图像坐标）
 */
export interface LocalHandKeyPoint {
  x: number
  y: number
  score: number
}

/**
 * 本地手框（原始图像坐标）
 */
export interface LocalHandRect {
  left: number
  top: number
  width: number
  height: number
}

/**
 * 本地手部检测结果
 */
export interface LocalHandDetectResult {
  hasHand: boolean
  points: Array<LocalHandKeyPoint>
  box?: LocalHandRect
}