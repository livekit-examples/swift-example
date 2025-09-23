/*
 * Copyright 2025 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if os(visionOS)

import RealityKit
import SwiftUI

struct ImmersiveView: View {
    var body: some View {
        ZStack {
            RealityView { content in
                let entity = Entity()
                entity.components.set(ModelComponent(
                    mesh: .generateSphere(radius: 1000),
                    materials: []
                ))

                entity.scale *= SIMD3(repeating: -1)
                content.add(entity)
            }
        }
    }
}
#endif
