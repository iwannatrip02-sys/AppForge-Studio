import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ExportServiceSTEP")

class ExportServiceSTEP {

    private var idCounter: Int = 0

    func exportToSTEP(sketchLines: [(CGPoint, CGPoint)], outputURL: URL) throws -> Bool {
        idCounter = 10

        var content = ""
        content += "ISO-10303-21;\n"
        content += "HEADER;\n"
        content += "FILE_DESCRIPTION(('CAD Sketch Export'),'2;1');\n"
        content += "FILE_NAME('sketch_export.stp','\(ISO8601DateFormatter().string(from: Date()))',"
        content += "('AppForgeStudio'),('AppForge'),'','','');\n"
        content += "FILE_SCHEMA(('CONFIG_CONTROL_DESIGN'));\n"
        content += "ENDSEC;\n"
        content += "DATA;\n"

        var lineEntities: [String] = []

        for (i, line) in sketchLines.enumerated() {
            let cpID1 = nextID()
            let cpID2 = nextID()

            content += "#\(cpID1)=CARTESIAN_POINT('',(\(format(line.0.x)),\(format(line.0.y)),0.0));\n"
            content += "#\(cpID2)=CARTESIAN_POINT('',(\(format(line.1.x)),\(format(line.1.y)),0.0));\n"

            let dirID = nextID()
            let dx = line.1.x - line.0.x
            let dy = line.1.y - line.0.y
            let dz: CGFloat = 0
            let length = sqrt(dx * dx + dy * dy + dz * dz)
            let nx = length > 0 ? dx / length : 0
            let ny = length > 0 ? dy / length : 0
            let nz: CGFloat = length > 0 ? dz / length : 0
            content += "#\(dirID)=DIRECTION('',(\(format(nx)),\(format(ny)),\(format(nz)));\n"

            let vecID = nextID()
            content += "#\(vecID)=VECTOR('',#\(dirID),\(format(length)));\n"

            let lineID = nextID()
            content += "#\(lineID)=LINE('',#\(cpID1),#\(vecID));\n"

            let ecID = nextID()
            content += "#\(ecID)=EDGE_CURVE('',#\(cpID1),#\(cpID2),#\(lineID),.T.);\n"

            let oeID = nextID()
            content += "#\(oeID)=ORIENTED_EDGE('',*,*,#\(ecID),.T.);\n"

            lineEntities.append("#\(oeID)")
        }

        if !lineEntities.isEmpty {
            let elsID = nextID()
            content += "#\(elsID)=EDGE_LOOP('',(\(lineEntities.joined(separator: ","))));\n"
        }

        content += "ENDSEC;\n"
        content += "END-ISO-10303-21;\n"

        try content.write(to: outputURL, atomically: true, encoding: .utf8)
        logger.info("STEP exported to \(outputURL.path)")
        return true
    }

    func exportMeshToSTEP(mesh: Mesh, outputURL: URL) throws -> Bool {
        idCounter = 0

        var content = ""
        content += "ISO-10303-21;\n"
        content += "HEADER;\n"
        content += "FILE_DESCRIPTION(('AppForgeStudio 3D Mesh Export'),'2;1');\n"
        content += "FILE_NAME('mesh_export.stp','\(ISO8601DateFormatter().string(from: Date()))',"
        content += "('AppForgeStudio'),('AppForge'),'','','');\n"
        content += "FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));\n"
        content += "ENDSEC;\n"
        content += "DATA;\n"

        let vIDs = mesh.vertices.map { v -> Int in
            let id = nextID()
            content += "#\(id)=CARTESIAN_POINT('',(\(fmt3(v.position.x)),\(fmt3(v.position.y)),\(fmt3(v.position.z))));\n"
            return id
        }

        var faceIDs: [Int] = []

        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = Int(mesh.indices[i])
            let b = Int(mesh.indices[i+1])
            let c = Int(mesh.indices[i+2])

            let pa = mesh.vertices[a].position
            let pb = mesh.vertices[b].position
            let pc = mesh.vertices[c].position

            let e1 = createEdgeCurve(from: vIDs[a], p1: pa, to: vIDs[b], p2: pb, content: &content)
            let e2 = createEdgeCurve(from: vIDs[b], p1: pb, to: vIDs[c], p2: pc, content: &content)
            let e3 = createEdgeCurve(from: vIDs[c], p1: pc, to: vIDs[a], p2: pa, content: &content)

            let oe1 = nextID(); content += "#\(oe1)=ORIENTED_EDGE('',*,*,#\(e1),.T.);\n"
            let oe2 = nextID(); content += "#\(oe2)=ORIENTED_EDGE('',*,*,#\(e2),.T.);\n"
            let oe3 = nextID(); content += "#\(oe3)=ORIENTED_EDGE('',*,*,#\(e3),.T.);\n"

            let elID = nextID()
            content += "#\(elID)=EDGE_LOOP('',(#\(oe1),#\(oe2),#\(oe3)));\n"

            let fbID = nextID()
            content += "#\(fbID)=FACE_BOUND('',#\(elID),.T.);\n"

            let normal = simd_cross(pb - pa, pc - pa)
            let planeID = createPlane(at: pa, normal: normal, content: &content)

            let fID = nextID()
            content += "#\(fID)=ADVANCED_FACE('',(#\(fbID)),#\(planeID),.T.);\n"
            faceIDs.append(fID)
        }

        let csID = nextID()
        let facesStr = faceIDs.map { "#\($0)" }.joined(separator: ",")
        content += "#\(csID)=CLOSED_SHELL('',(\(facesStr)));\n"

        let msID = nextID()
        content += "#\(msID)=MANIFOLD_SOLID_BREP('',#\(csID));\n"

        content += "ENDSEC;\n"
        content += "END-ISO-10303-21;\n"

        try content.write(to: outputURL, atomically: true, encoding: .utf8)
        logger.info("STEP 3D mesh exported to \(outputURL.path)")
        return true
    }

    private func createEdgeCurve(from p1ID: Int, p1: SIMD3<Float>, to p2ID: Int, p2: SIMD3<Float>, content: inout String) -> Int {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let dz = p2.z - p1.z
        let len = sqrt(dx*dx + dy*dy + dz*dz)

        let dirID = nextID()
        if len > 1e-8 {
            content += "#\(dirID)=DIRECTION('',(\(fmt3(dx/len)),\(fmt3(dy/len)),\(fmt3(dz/len))));\n"
        } else {
            content += "#\(dirID)=DIRECTION('',(1.0,0.0,0.0));\n"
        }
        let vecID = nextID()
        content += "#\(vecID)=VECTOR('',#\(dirID),\(fmt3(len)));\n"
        let lineID = nextID()
        content += "#\(lineID)=LINE('',#\(p1ID),#\(vecID));\n"
        let edgeID = nextID()
        content += "#\(edgeID)=EDGE_CURVE('',#\(p1ID),#\(p2ID),#\(lineID),.T.);\n"
        return edgeID
    }

    private func createPlane(at point: SIMD3<Float>, normal: SIMD3<Float>, content: inout String) -> Int {
        let originID = nextID()
        content += "#\(originID)=CARTESIAN_POINT('',(\(fmt3(point.x)),\(fmt3(point.y)),\(fmt3(point.z))));\n"

        let zDirID = nextID()
        let nLen = simd_length(normal)
        if nLen > 1e-8 {
            let n = normal / nLen
            content += "#\(zDirID)=DIRECTION('',(\(fmt3(n.x)),\(fmt3(n.y)),\(fmt3(n.z))));\n"
        } else {
            content += "#\(zDirID)=DIRECTION('',(0.0,0.0,1.0));\n"
        }

        let axisID = nextID()
        content += "#\(axisID)=AXIS2_PLACEMENT_3D('',#\(originID),#\(zDirID));\n"
        let planeID = nextID()
        content += "#\(planeID)=PLANE('',#\(axisID));\n"
        return planeID
    }

    private func fmt3(_ value: Float) -> String {
        String(format: "%.6f", Double(value))
    }

    private func nextID() -> Int {
        idCounter += 1
        return idCounter
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.6f", Double(value))
    }
}
