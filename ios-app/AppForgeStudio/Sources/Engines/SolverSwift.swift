import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SolverSwift")

// MARK: - Solver parametrico 2D en Swift puro
// Reemplaza SolveSpaceSolver (solo structs Slvs vacios sin binding C++)
// Usa metodo Newton-Raphson con matriz Jacobiana para constraints geometricos

struct SolverPoint {
    let id: UUID
    var x: Double
    var y: Double
    var isFixed: Bool
}

enum SolverConstraintType {
    case horizontal(pointID: UUID)
    case vertical(pointID: UUID)
    case coincident(pointA: UUID, pointB: UUID)
    case distance(pointA: UUID, pointB: UUID, value: Double)
    case angle(pointA: UUID, pointB: UUID, pointC: UUID, value: Double)
    case parallel(lineAStart: UUID, lineAEnd: UUID, lineBStart: UUID, lineBEnd: UUID)
    case perpendicular(lineAStart: UUID, lineAEnd: UUID, lineBStart: UUID, lineBEnd: UUID)
    case equal(pointA: UUID, pointB: UUID, pointC: UUID, pointD: UUID)
    case midpoint(pointA: UUID, pointB: UUID, pointMid: UUID)
    case concentric(circleCenterA: UUID, circleCenterB: UUID)
    case collinear(pointA: UUID, pointB: UUID, pointC: UUID)
    case tangent(center: UUID, point: UUID, radius: Double)
}

struct SolverConstraint {
    let id: UUID
    let type: SolverConstraintType
    let weight: Double
}

struct SolverResult {
    let converged: Bool
    let iterations: Int
    let residual: Double
    let points: [SolverPoint]
}

class SolverSwift {
    private var points: [UUID: SolverPoint] = [:]
    private var constraints: [SolverConstraint] = []
    
    private let maxIter = 100
    private let tol = 1e-8
    private let damping: Double = 0.3
    
    func addPoint(_ p: SolverPoint) { points[p.id] = p }
    func addConstraint(_ c: SolverConstraint) { constraints.append(c) }
    func removeConstraint(id: UUID) { constraints.removeAll { $0.id == id } }
    func clear() { points.removeAll(); constraints.removeAll() }
    
    func solve() -> SolverResult {
        if constraints.isEmpty {
            return SolverResult(converged: true, iterations: 0, residual: 0, points: Array(points.values))
        }
        var freeVars: [UUID] = []
        var x: [Double] = []
        for (id, p) in points where !p.isFixed {
            freeVars.append(id)
            x.append(p.x)
            x.append(p.y)
        }
        if freeVars.isEmpty {
            return SolverResult(converged: true, iterations: 0, residual: 0, points: Array(points.values))
        }
        var prevResidual = Double.infinity
        for iter in 0..<maxIter {
            var tempPoints = points
            for (i, id) in freeVars.enumerated() {
                if var pt = tempPoints[id] {
                    pt.x = x[i*2]
                    pt.y = x[i*2+1]
                    tempPoints[id] = pt
                }
            }
            var f: [Double] = []
            var J: [[Double]] = []
            let n = x.count
            for constraint in constraints {
                let (fi, Ji) = evalConstraint(constraint, pts: tempPoints, freeIdx: freeVars, n: n)
                f.append(contentsOf: fi)
                for row in Ji { J.append(row) }
            }
            if f.isEmpty { break }
            let sq = f.reduce(0) { $0 + $1*$1 }
            let residual = sqrt(sq / Double(f.count))
            if residual < tol {
                apply(x, ids: freeVars)
                return SolverResult(converged: true, iterations: iter, residual: residual, points: Array(points.values))
            }
            if residual > prevResidual {
                let step = solveLin(J, f: f)
                for i in 0..<x.count { x[i] -= step[i] * damping * 0.5 }
            } else {
                let step = solveLin(J, f: f)
                for i in 0..<x.count { x[i] -= step[i] * damping }
            }
            prevResidual = residual
        }
        apply(x, ids: freeVars)
        return SolverResult(converged: false, iterations: maxIter, residual: prevResidual, points: Array(points.values))
    }
    
    private func evalConstraint(_ c: SolverConstraint, pts: [UUID: SolverPoint], freeIdx: [UUID], n: Int) -> ([Double], [[Double]]) {
        switch c.type {
        case .horizontal(let pid):
            guard let p = pts[pid] else { return ([], []) }
            var row = [Double](repeating: 0, count: n)
            if let i = freeIdx.firstIndex(of: pid) { row[i*2+1] = 1.0 }
            return ([p.y], [row])
        case .vertical(let pid):
            guard let p = pts[pid] else { return ([], []) }
            var row = [Double](repeating: 0, count: n)
            if let i = freeIdx.firstIndex(of: pid) { row[i*2] = 1.0 }
            return ([p.x], [row])
        case .coincident(let a, let b):
            guard let pa = pts[a], let pb = pts[b] else { return ([], []) }
            let dx = pb.x - pa.x
            let dy = pb.y - pa.y
            var rx = [Double](repeating: 0, count: n)
            var ry = [Double](repeating: 0, count: n)
            if let ia = freeIdx.firstIndex(of: a) { rx[ia*2] = -1; ry[ia*2+1] = -1 }
            if let ib = freeIdx.firstIndex(of: b) { rx[ib*2] += 1; ry[ib*2+1] += 1 }
            return ([dx, dy], [rx, ry])
        case .distance(let a, let b, let val):
            guard let pa = pts[a], let pb = pts[b] else { return ([], []) }
            let dx = pb.x - pa.x
            let dy = pb.y - pa.y
            let dist = sqrt(dx*dx + dy*dy)
            let err = dist - val
            var row = [Double](repeating: 0, count: n)
            if dist > 1e-12 {
                if let ia = freeIdx.firstIndex(of: a) { row[ia*2] = -dx/dist; row[ia*2+1] = -dy/dist }
                if let ib = freeIdx.firstIndex(of: b) { row[ib*2] += dx/dist; row[ib*2+1] += dy/dist }
            }
            return ([err], [row])
        case .parallel(let a1, let a2, let b1, let b2):
            guard let p1 = pts[a1], let p2 = pts[a2], let q1 = pts[b1], let q2 = pts[b2] else { return ([], []) }
            let dx1 = p2.x - p1.x
            let dy1 = p2.y - p1.y
            let dx2 = q2.x - q1.x
            let dy2 = q2.y - q1.y
            let f = dx1 * dy2 - dy1 * dx2
            var row = [Double](repeating: 0, count: n)
            if let ia1 = freeIdx.firstIndex(of: a1) { row[ia1*2] = -dy2; row[ia1*2+1] = dx2 }
            if let ia2 = freeIdx.firstIndex(of: a2) { row[ia2*2] = dy2; row[ia2*2+1] = -dx2 }
            if let ib1 = freeIdx.firstIndex(of: b1) { row[ib1*2] = dy1; row[ib1*2+1] = -dx1 }
            if let ib2 = freeIdx.firstIndex(of: b2) { row[ib2*2] = -dy1; row[ib2*2+1] = dx1 }
            return ([f], [row])
        case .perpendicular(let a1, let a2, let b1, let b2):
            guard let p1 = pts[a1], let p2 = pts[a2], let q1 = pts[b1], let q2 = pts[b2] else { return ([], []) }
            let dx1 = p2.x - p1.x
            let dy1 = p2.y - p1.y
            let dx2 = q2.x - q1.x
            let dy2 = q2.y - q1.y
            let f = dx1 * dx2 + dy1 * dy2
            var row = [Double](repeating: 0, count: n)
            if let ia1 = freeIdx.firstIndex(of: a1) { row[ia1*2] = -dx2; row[ia1*2+1] = -dy2 }
            if let ia2 = freeIdx.firstIndex(of: a2) { row[ia2*2] = dx2; row[ia2*2+1] = dy2 }
            if let ib1 = freeIdx.firstIndex(of: b1) { row[ib1*2] = -dx1; row[ib1*2+1] = -dy1 }
            if let ib2 = freeIdx.firstIndex(of: b2) { row[ib2*2] = dx1; row[ib2*2+1] = dy1 }
            return ([f], [row])
        case .equal(let a, let b, let c, let d):
            guard let pa = pts[a], let pb = pts[b], let pc = pts[c], let pd = pts[d] else { return ([], []) }
            let dxAB = pb.x - pa.x
            let dyAB = pb.y - pa.y
            let dxCD = pd.x - pc.x
            let dyCD = pd.y - pc.y
            let f = (dxAB*dxAB + dyAB*dyAB) - (dxCD*dxCD + dyCD*dyCD)
            var row = [Double](repeating: 0, count: n)
            if let ia = freeIdx.firstIndex(of: a) { row[ia*2] = -2*dxAB; row[ia*2+1] = -2*dyAB }
            if let ib = freeIdx.firstIndex(of: b) { row[ib*2] = 2*dxAB; row[ib*2+1] = 2*dyAB }
            if let ic = freeIdx.firstIndex(of: c) { row[ic*2] = 2*dxCD; row[ic*2+1] = 2*dyCD }
            if let id = freeIdx.firstIndex(of: d) { row[id*2] = -2*dxCD; row[id*2+1] = -2*dyCD }
            return ([f], [row])
        case .angle(let a, let b, let c, let val):
            guard let pa = pts[a], let pb = pts[b], let pc = pts[c] else { return ([], []) }
            let dx1 = pa.x - pb.x
            let dy1 = pa.y - pb.y
            let dx2 = pc.x - pb.x
            let dy2 = pc.y - pb.y
            let cross = dx1 * dy2 - dy1 * dx2
            let dot = dx1 * dx2 + dy1 * dy2
            let currentAngle = atan2(cross, dot)
            let err = currentAngle - val
            let D = max((dx1*dx1 + dy1*dy1) * (dx2*dx2 + dy2*dy2), 1e-12)
            let dAtanCross = dot / D
            let dAtanDot = -cross / D
            var row = [Double](repeating: 0, count: n)
            if let ia = freeIdx.firstIndex(of: a) {
                row[ia*2]   = dAtanCross * dy2 + dAtanDot * dx2
                row[ia*2+1] = dAtanCross * (-dx2) + dAtanDot * dy2
            }
            if let ib = freeIdx.firstIndex(of: b) {
                row[ib*2]   = dAtanCross * (dy1 - dy2) + dAtanDot * (-dx2 - dx1)
                row[ib*2+1] = dAtanCross * (dx2 - dx1) + dAtanDot * (-dy2 - dy1)
            }
            if let ic = freeIdx.firstIndex(of: c) {
                row[ic*2]   = dAtanCross * (-dy1) + dAtanDot * dx1
                row[ic*2+1] = dAtanCross * dx1 + dAtanDot * dy1
            }
            return ([err], [row])
        case .midpoint(let a, let b, let m):
            guard let pa = pts[a], let pb = pts[b], let pm = pts[m] else { return ([], []) }
            let fx = (pa.x + pb.x) / 2.0 - pm.x
            let fy = (pa.y + pb.y) / 2.0 - pm.y
            var rx = [Double](repeating: 0, count: n)
            var ry = [Double](repeating: 0, count: n)
            if let ia = freeIdx.firstIndex(of: a) { rx[ia*2] = 0.5; ry[ia*2+1] = 0.5 }
            if let ib = freeIdx.firstIndex(of: b) { rx[ib*2] = 0.5; ry[ib*2+1] = 0.5 }
            if let im = freeIdx.firstIndex(of: m) { rx[im*2] = -1.0; ry[im*2+1] = -1.0 }
            return ([fx, fy], [rx, ry])
        case .concentric(let a, let b):
            guard let pa = pts[a], let pb = pts[b] else { return ([], []) }
            let dx = pb.x - pa.x
            let dy = pb.y - pa.y
            var rx = [Double](repeating: 0, count: n)
            var ry = [Double](repeating: 0, count: n)
            if let ia = freeIdx.firstIndex(of: a) { rx[ia*2] = -1; ry[ia*2+1] = -1 }
            if let ib = freeIdx.firstIndex(of: b) { rx[ib*2] = 1; ry[ib*2+1] = 1 }
            return ([dx, dy], [rx, ry])
        case .tangent(let center, let point, let radius):
            guard let pc = pts[center], let pp = pts[point] else { return ([], []) }
            let dx = pp.x - pc.x
            let dy = pp.y - pc.y
            let dist = sqrt(dx*dx + dy*dy)
            let err = dist - radius
            var row = [Double](repeating: 0, count: n)
            if dist > 1e-12 {
                if let ic = freeIdx.firstIndex(of: center) { row[ic*2] = -dx/dist; row[ic*2+1] = -dy/dist }
                if let ip = freeIdx.firstIndex(of: point) { row[ip*2] += dx/dist; row[ip*2+1] += dy/dist }
            }
            return ([err], [row])
        case .collinear(let a, let b, let c):
            guard let pa = pts[a], let pb = pts[b], let pc = pts[c] else { return ([], []) }
            let area = (pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x)
            var row = [Double](repeating: 0, count: n)
            if let ia = freeIdx.firstIndex(of: a) {
                row[ia*2]   = pb.y - pc.y
                row[ia*2+1] = pc.x - pb.x
            }
            if let ib = freeIdx.firstIndex(of: b) {
                row[ib*2]   = pc.y - pa.y
                row[ib*2+1] = pa.x - pc.x
            }
            if let ic = freeIdx.firstIndex(of: c) {
                row[ic*2]   = pa.y - pb.y
                row[ic*2+1] = pb.x - pa.x
            }
            return ([area], [row])
        }
    }
    
    private func solveLin(_ J: [[Double]], f: [Double]) -> [Double] {
        let m = f.count
        if m == 0 { return [] }
        let n = J.first?.count ?? 0
        if n == 0 { return [] }
        var A = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        var b = [Double](repeating: 0, count: n)
        for i in 0..<m {
            for j in 0..<n {
                for k in 0..<n {
                    A[j][k] += J[i][j] * J[i][k]
                }
                b[j] += J[i][j] * f[i]
            }
        }
        for i in 0..<n { A[i][i] += 1e-8 }
        return gaussSeidel(A, b, n: n)
    }
    
    private func gaussSeidel(_ A: [[Double]], _ b: [Double], n: Int) -> [Double] {
        var x = [Double](repeating: 0, count: n)
        for _ in 0..<50 {
            var maxDiff = 0.0
            for i in 0..<n {
                var s = b[i]
                for j in 0..<n where j != i { s -= A[i][j] * x[j] }
                if abs(A[i][i]) > 1e-12 {
                    let old = x[i]
                    x[i] = s / A[i][i]
                    maxDiff = max(maxDiff, abs(x[i] - old))
                }
            }
            if maxDiff < 1e-10 { break }
        }
        return x
    }
    
    private func apply(_ x: [Double], ids: [UUID]) {
        for (i, id) in ids.enumerated() {
            if var p = points[id] {
                p.x = x[i*2]
                p.y = x[i*2+1]
                points[id] = p
            }
        }
    }
}
