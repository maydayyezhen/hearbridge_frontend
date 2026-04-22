export interface LocalHandKeyPoint {
  x: number
  y: number
  score: number
}

export interface LocalHandRect {
  left: number
  top: number
  width: number
  height: number
}

export interface LocalHandDetectResult {
  hasHand: boolean
  points: Array<LocalHandKeyPoint>
  box?: LocalHandRect
}

declare const handDetector: {
  detectFromJpeg(
    jpegBytes: ArrayBuffer,
    width: number,
    height: number,
    rotation: number
  ): LocalHandDetectResult
}

export default handDetector