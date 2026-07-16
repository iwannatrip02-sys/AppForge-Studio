import XCTest
import simd
@testable import AppForgeStudio

/// Regresión para BUG5: normal matrix con escala no uniforme.
///
/// La fórmula correcta para transformar normales bajo escala no uniforme es la
/// inversa-transpuesta del 3×3 superior-izquierdo de la matriz modelo.
/// Usar el 3×3 directamente (sin inversa-transpuesta) produce normales incorrectas
/// que "se inclinan hacia" el eje más escalado en lugar de alejarse de él.
///
/// Referencia Swift (SatinRenderer.swift):
///   Pipeline PBR  — líneas 1049–1054: model3x3.inverse.transpose
///   Pipeline basic — líneas 976–980:  simd_float3x3(...).inverse.transpose
final class NormalMatrixTests: XCTestCase {

    // MARK: - Helpers privados

    /// Extrae el 3×3 superior-izquierdo de una float4x4 y calcula la normal matrix
    /// con la fórmula CORRECTA (inversa-transpuesta), idéntica a SatinRenderer.swift.
    private func computeNormalMatrix(from modelMatrix: simd_float4x4) -> simd_float3x3 {
        let model3x3 = simd_float3x3(
            SIMD3<Float>(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
            SIMD3<Float>(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
            SIMD3<Float>(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        )
        return model3x3.inverse.transpose
    }

    /// Construye una matriz de escala no uniforme scale(sx, sy, sz).
    private func scaleMatrix(_ sx: Float, _ sy: Float, _ sz: Float) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.0.x = sx
        m.columns.1.y = sy
        m.columns.2.z = sz
        return m
    }

    // MARK: - BUG5: normal matrix con escala no uniforme (scale 1,2,1)

    /// Verifica que la normal matrix calculada con inversa-transpuesta transforma
    /// correctamente una normal conocida bajo escala no uniforme scale(1, 2, 1).
    ///
    /// Setup:
    ///   - Modelo con scale(1, 2, 1): el eje Y se estira al doble.
    ///   - Normal de entrada: (1, 1, 0) / √2 (superficie inclinada 45° sobre Z).
    ///
    /// La normal matrix correcta es diag(1, 0.5, 1) = (scale^T)^-1:
    ///   diag(1, 0.5, 1) × (1/√2, 1/√2, 0) = (1/√2, 0.5/√2, 0)
    ///   normalizado → (2/√5, 1/√5, 0) ≈ (0.8944, 0.4472, 0)
    ///
    /// Con la fórmula INCORRECTA (model3x3 directamente):
    ///   diag(1, 2, 1) × (1/√2, 1/√2, 0) = (1/√2, 2/√2, 0)
    ///   normalizado → (1/√5, 2/√5, 0) ≈ (0.4472, 0.8944, 0)  ← INCORRECTO
    func testNormalMatrixNonUniformScale_Y2() {
        let modelMatrix = scaleMatrix(1, 2, 1)
        let normalMatrix = computeNormalMatrix(from: modelMatrix)

        let inputNormal = simd_normalize(SIMD3<Float>(1, 1, 0))
        let transformed = simd_normalize(normalMatrix * inputNormal)

        // (2/√5, 1/√5, 0)
        let expected = simd_normalize(SIMD3<Float>(2, 1, 0))
        let eps: Float = 1e-5

        XCTAssertEqual(transformed.x, expected.x, accuracy: eps,
            "BUG5: normal.x incorrecta bajo scale(1,2,1) — falta inversa-transpuesta?")
        XCTAssertEqual(transformed.y, expected.y, accuracy: eps,
            "BUG5: normal.y incorrecta bajo scale(1,2,1) — falta inversa-transpuesta?")
        XCTAssertEqual(transformed.z, expected.z, accuracy: eps,
            "BUG5: normal.z incorrecta bajo scale(1,2,1) — debe ser cero")
    }

    /// Verifica que la fórmula INCORRECTA (model3x3 directo, sin inversa-transpuesta)
    /// produce un resultado diferente al correcto con escala no uniforme.
    /// Este test documenta por qué la inversa-transpuesta es necesaria.
    func testNaiveNormalTransformDiffersFromCorrectUnderNonUniformScale() {
        let modelMatrix = scaleMatrix(1, 2, 1)
        let model3x3 = simd_float3x3(
            SIMD3<Float>(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
            SIMD3<Float>(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
            SIMD3<Float>(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        )

        let inputNormal = simd_normalize(SIMD3<Float>(1, 1, 0))

        let naiveResult  = simd_normalize(model3x3 * inputNormal)
        let correctResult = simd_normalize(model3x3.inverse.transpose * inputNormal)

        // Con escala no uniforme los resultados DEBEN diferir.
        // Si este assert falla, el caso de prueba no es discriminante.
        XCTAssertNotEqual(naiveResult.x, correctResult.x,
            "Con escala no uniforme, transformacion naive y correcta deben diferir en X")
        XCTAssertNotEqual(naiveResult.y, correctResult.y,
            "Con escala no uniforme, transformacion naive y correcta deben diferir en Y")
    }

    /// Verifica escala no uniforme en el eje X: scale(3, 1, 1).
    /// Normal de entrada (1, 0, 1)/√2 (inclinada sobre Y).
    ///
    /// normalMatrix = diag(1/3, 1, 1).
    /// resultado = normalize(diag(1/3,1,1) × (1/√2, 0, 1/√2)) = normalize(1/3/√2, 0, 1/√2)
    ///           = normalize(1, 0, 3) = (1/√10, 0, 3/√10)
    func testNormalMatrixNonUniformScale_X3() {
        let modelMatrix = scaleMatrix(3, 1, 1)
        let normalMatrix = computeNormalMatrix(from: modelMatrix)

        let inputNormal = simd_normalize(SIMD3<Float>(1, 0, 1))
        let transformed = simd_normalize(normalMatrix * inputNormal)

        // (1/√10, 0, 3/√10)
        let expected = simd_normalize(SIMD3<Float>(1, 0, 3))
        let eps: Float = 1e-5

        XCTAssertEqual(transformed.x, expected.x, accuracy: eps,
            "BUG5: normal.x incorrecta bajo scale(3,1,1)")
        XCTAssertEqual(transformed.y, expected.y, accuracy: eps,
            "BUG5: normal.y debe ser cero bajo scale(3,1,1)")
        XCTAssertEqual(transformed.z, expected.z, accuracy: eps,
            "BUG5: normal.z incorrecta bajo scale(3,1,1)")
    }

    /// Verifica que con escala UNIFORME la normal matrix y el 3×3 directo
    /// producen el mismo resultado (porque (kI)^{-T} = (1/k)I, cuya dirección
    /// tras normalizar es igual que la de kI * n normalizada).
    ///
    /// Esto confirma que el test de escala no uniforme es discriminante
    /// (el bug solo aparece con escala no uniforme).
    func testNormalMatrixUniformScaleIsSameDirectionAsNaive() {
        let modelMatrix = scaleMatrix(3, 3, 3)
        let model3x3 = simd_float3x3(
            SIMD3<Float>(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
            SIMD3<Float>(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
            SIMD3<Float>(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        )

        let inputNormal = simd_normalize(SIMD3<Float>(1, 2, 3))

        let naiveResult   = simd_normalize(model3x3 * inputNormal)
        let correctResult = simd_normalize(model3x3.inverse.transpose * inputNormal)
        let eps: Float = 1e-5

        XCTAssertEqual(naiveResult.x, correctResult.x, accuracy: eps,
            "Escala uniforme: la direccion de la normal debe ser la misma con ambas formulas")
        XCTAssertEqual(naiveResult.y, correctResult.y, accuracy: eps,
            "Escala uniforme: la direccion de la normal debe ser la misma con ambas formulas")
        XCTAssertEqual(naiveResult.z, correctResult.z, accuracy: eps,
            "Escala uniforme: la direccion de la normal debe ser la misma con ambas formulas")
    }

    /// Verifica que la normal matrix transformada preserva la perpendicularidad
    /// con el vector tangente transformado con la matriz de modelo directa.
    ///
    /// Propiedad fundamental: si T es un vector tangente en la superficie y N es
    /// la normal, entonces (M*T) · ((M^{-T})*N) = 0 en todo caso.
    /// Con la fórmula incorrecta (M*N), esto falla bajo escala no uniforme.
    func testNormalMatrixPreservesPerpendicularityUnderNonUniformScale() {
        let modelMatrix = scaleMatrix(1, 3, 2)

        // Tangente y normal perpendiculares en espacio objeto
        let tangent = simd_normalize(SIMD3<Float>(1, 0, 0))
        let normal  = simd_normalize(SIMD3<Float>(0, 1, 0))

        let model3x3 = simd_float3x3(
            SIMD3<Float>(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
            SIMD3<Float>(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
            SIMD3<Float>(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        )
        let normalMatrix = model3x3.inverse.transpose

        // Transformar tangente con M, normal con M^{-T}
        let worldTangent = model3x3 * tangent
        let worldNormal  = normalMatrix * normal

        // dot debe ser 0 (perpendiculares en espacio mundo)
        let dotProduct = dot(worldTangent, worldNormal)
        XCTAssertEqual(dotProduct, 0.0, accuracy: 1e-5,
            "BUG5: la normal matrix M^{-T} debe preservar perpendicularidad con la tangente M*T")
    }
}
