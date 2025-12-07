import bpy
import math
import os

# 기존 오브젝트 정리
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# ============================================================================
# 파라미터 설정 (최적화 버전)
# ============================================================================
dice_size = 2.0          # 주사위 크기
pip_size = 0.35          # 눈(pip) 크기
pip_depth = 0.25         # 눈이 들어간 깊이
bevel_amount = 0.08      # 주사위 모서리 둥글기

# 각 면에서 눈의 위치 오프셋 (중심 기준)
pip_spacing = 0.5        # 눈 사이 간격

# ★★★ 최적화: 모든 subdivide 제거 (매끄러운 주사위) ★★★
pip_subdivisions = 0     # 눈 표면 subdivide 제거
pip_displacement = 0.0   # 눈 표면 displacement 제거

dice_subdivisions = 0    # 주사위 본체 subdivide 제거
dice_displacement = 0.0  # 주사위 본체 displacement 제거

edge_subdivisions = 0    # 모서리 subdivide 제거
edge_displacement = 0.0  # 모서리 displacement 제거
edge_bevel_segments = 2  # Bevel 세그먼트는 유지 (부드러운 모서리)

# 주사위 색상 팔레트
dice_colors = {
    "Red": (1.0, 0.0, 0.0, 1.0),
    "Blue": (0.0, 0.0, 1.0, 1.0),
    "Green": (0.0, 1.0, 0.0, 1.0),
    "White": (1.0, 1.0, 1.0, 1.0),
    "Black": (0.1, 0.1, 0.1, 1.0),
}

# 각 주사위 색상에 따른 눈 색상
pip_colors = {
    "Red": (0.0, 0.0, 0.0, 1.0),      # 검은색 눈
    "Blue": (0.0, 0.0, 0.0, 1.0),     # 검은색 눈
    "Green": (0.0, 0.0, 0.0, 1.0),    # 검은색 눈
    "White": (0.0, 0.0, 0.0, 1.0),    # 검은색 눈
    "Black": (1.0, 1.0, 1.0, 1.0),    # 흰색 눈
}

# 생성할 주사위 선택 (원하는 색상만 True로 설정)
create_dice = {
    "Red": True,
    "Blue": True,
    "Green": True,
    "White": True,
    "Black": True,
}

print("=" * 70)
print("주사위 생성 시작 (최적화 버전 - 매끄러운 표면)")
print("=" * 70)

# 생성할 색상 필터링
colors_to_create = [color_name for color_name, should_create in create_dice.items() if should_create]
print(f"\n생성할 주사위: {', '.join(colors_to_create)}")

# ============================================================================
# 각 색상별로 주사위 생성
# ============================================================================
dice_spacing_x = dice_size * 3  # 주사위 사이 간격

for dice_index, color_name in enumerate(colors_to_create):
    dice_color = dice_colors[color_name]
    x_offset = dice_index * dice_spacing_x

    print(f"\n{'=' * 70}")
    print(f"[{color_name} 주사위 생성 중]")
    print(f"{'=' * 70}")

    # ============================================================================
    # STEP 1: 주사위 본체 생성 (매끄러운 표면)
    # ============================================================================
    print("\n[STEP 1] 주사위 본체 생성")

    bpy.ops.mesh.primitive_cube_add(size=dice_size, location=(x_offset, 0, 0))
    dice_body = bpy.context.active_object
    dice_body.name = f"Dice_Body_{color_name}"

    # Bevel로 모서리 둥글게
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.bevel(offset=bevel_amount, segments=edge_bevel_segments, profile=0.5)
    bpy.ops.object.mode_set(mode='OBJECT')

    print(f"  ✅ {color_name} 주사위 본체 완성 (매끄러운 표면)")

    # ============================================================================
    # STEP 2: 각 면에 눈(pip) 배치 정의
    # ============================================================================
    print("\n[STEP 2] 눈 배치 패턴 정의")

    # 각 면의 눈 패턴 정의 (x, y 좌표)
    pip_patterns = {
        1: [(0, 0)],  # 1: 중앙
        2: [(-pip_spacing, pip_spacing), (pip_spacing, -pip_spacing)],  # 2: 대각선
        3: [(-pip_spacing, pip_spacing), (0, 0), (pip_spacing, -pip_spacing)],  # 3: 대각선 + 중앙
        4: [(-pip_spacing, pip_spacing), (pip_spacing, pip_spacing),  # 4: 네 모서리
            (-pip_spacing, -pip_spacing), (pip_spacing, -pip_spacing)],
        5: [(-pip_spacing, pip_spacing), (pip_spacing, pip_spacing),  # 5: 네 모서리 + 중앙
            (0, 0),
            (-pip_spacing, -pip_spacing), (pip_spacing, -pip_spacing)],
        6: [(-pip_spacing, pip_spacing), (pip_spacing, pip_spacing),  # 6: 양쪽 3개씩
            (-pip_spacing, 0), (pip_spacing, 0),
            (-pip_spacing, -pip_spacing), (pip_spacing, -pip_spacing)],
    }

    # 각 면의 방향 정의
    faces = [
        (1, (0, 0, 1), (0, 0, 0)),           # 위쪽 (Z+)
        (6, (0, 0, -1), (180, 0, 0)),        # 아래쪽 (Z-)
        (2, (1, 0, 0), (0, 90, 0)),          # 오른쪽 (X+)
        (5, (-1, 0, 0), (0, -90, 0)),        # 왼쪽 (X-)
        (3, (0, 1, 0), (-90, 0, 0)),         # 앞쪽 (Y+)
        (4, (0, -1, 0), (90, 0, 0)),         # 뒤쪽 (Y-)
    ]

    print("  ✅ 6개 면 패턴 정의 완료")

    # ============================================================================
    # STEP 3: 각 면에 눈(pip) 생성
    # ============================================================================
    print("\n[STEP 3] 눈(pip) 생성")

    all_pips = []
    pip_count = 0

    for face_value, normal, rotation in faces:
        pattern = pip_patterns[face_value]
        print(f"  면 {face_value}: {len(pattern)}개 눈 생성")

        for pip_x, pip_y in pattern:
            # 큐브 생성
            bpy.ops.mesh.primitive_cube_add(
                size=pip_size,
                location=(0, 0, 0)
            )
            pip = bpy.context.active_object
            pip.name = f"Pip_{color_name}_Face{face_value}_{pip_count}"
            pip_count += 1

            # 위치 설정
            half_dice = dice_size / 2

            if normal == (0, 0, 1):  # 위쪽
                pip.location = (x_offset + pip_x, pip_y, half_dice + pip_depth/2)
            elif normal == (0, 0, -1):  # 아래쪽
                pip.location = (x_offset + pip_x, pip_y, -half_dice - pip_depth/2)
            elif normal == (1, 0, 0):  # 오른쪽
                pip.location = (x_offset + half_dice + pip_depth/2, pip_x, pip_y)
            elif normal == (-1, 0, 0):  # 왼쪽
                pip.location = (x_offset - half_dice - pip_depth/2, pip_x, pip_y)
            elif normal == (0, 1, 0):  # 앞쪽
                pip.location = (x_offset + pip_x, half_dice + pip_depth/2, pip_y)
            elif normal == (0, -1, 0):  # 뒤쪽
                pip.location = (x_offset + pip_x, -half_dice - pip_depth/2, pip_y)

            all_pips.append(pip)

    print(f"  ✅ 총 {pip_count}개 눈 생성 완료")

    # ============================================================================
    # STEP 4: 주사위 본체에서 눈 부분 Boolean로 제거
    # ============================================================================
    print("\n[STEP 4] Boolean 연산으로 눈 파기")

    # 모든 pip을 하나로 합치기
    bpy.ops.object.select_all(action='DESELECT')
    for pip in all_pips:
        pip.select_set(True)
    bpy.context.view_layer.objects.active = all_pips[0]
    bpy.ops.object.join()

    combined_pips = bpy.context.active_object
    combined_pips.name = f"All_Pips_{color_name}"

    # Boolean Difference
    bpy.context.view_layer.objects.active = dice_body
    modifier = dice_body.modifiers.new(name="Subtract_Pips", type='BOOLEAN')
    modifier.operation = 'DIFFERENCE'
    modifier.object = combined_pips
    bpy.ops.object.modifier_apply(modifier="Subtract_Pips")

    bpy.data.objects.remove(combined_pips, do_unlink=True)

    print("  ✅ Boolean 연산 완료")

    # ============================================================================
    # STEP 5: 눈 구멍에 작은 큐브 채우기 (매끄러운 표면)
    # ============================================================================
    print("\n[STEP 5] 눈 구멍에 네모 채우기")

    pip_fills = []
    for face_value, normal, rotation in faces:
        pattern = pip_patterns[face_value]

        for pip_x, pip_y in pattern:
            # 작은 큐브 생성
            bpy.ops.mesh.primitive_cube_add(
                size=pip_size * 0.9,
                location=(0, 0, 0)
            )
            pip_fill = bpy.context.active_object
            pip_fill.name = f"PipFill_{color_name}_Face{face_value}"

            # 위치 설정
            half_dice = dice_size / 2
            inset = pip_depth * 0.7

            if normal == (0, 0, 1):  # 위쪽
                pip_fill.location = (x_offset + pip_x, pip_y, half_dice - inset)
            elif normal == (0, 0, -1):  # 아래쪽
                pip_fill.location = (x_offset + pip_x, pip_y, -half_dice + inset)
            elif normal == (1, 0, 0):  # 오른쪽
                pip_fill.location = (x_offset + half_dice - inset, pip_x, pip_y)
            elif normal == (-1, 0, 0):  # 왼쪽
                pip_fill.location = (x_offset - half_dice + inset, pip_x, pip_y)
            elif normal == (0, 1, 0):  # 앞쪽
                pip_fill.location = (x_offset + pip_x, half_dice - inset, pip_y)
            elif normal == (0, -1, 0):  # 뒤쪽
                pip_fill.location = (x_offset + pip_x, -half_dice + inset, pip_y)

            pip_fills.append(pip_fill)

    print("  ✅ 눈 채우기 완료 (매끄러운 표면)")

    # ============================================================================
    # STEP 6: 눈에 Material 적용
    # ============================================================================
    print("\n[STEP 6] 눈에 Material 적용")

    bpy.ops.object.select_all(action='DESELECT')
    for pip_fill in pip_fills:
        pip_fill.select_set(True)

    if len(pip_fills) > 0:
        bpy.context.view_layer.objects.active = pip_fills[0]
        bpy.ops.object.join()
        pips_combined = bpy.context.active_object
        pips_combined.name = f"Pips_Combined_{color_name}"

        # 눈 Material
        pip_mat = bpy.data.materials.new(name=f"Pip_Material_{color_name}")
        pip_mat.use_nodes = True
        pip_bsdf = pip_mat.node_tree.nodes.get("Principled BSDF")
        pip_bsdf.inputs['Base Color'].default_value = pip_colors[color_name]
        pip_bsdf.inputs['Roughness'].default_value = 0.4
        pip_bsdf.inputs['Metallic'].default_value = 0.0

        pips_combined.data.materials.append(pip_mat)
        print(f"  ✅ 눈에 Material 적용 완료")

    # ============================================================================
    # STEP 7: 주사위 본체 Material 적용
    # ============================================================================
    print("\n[STEP 7] 주사위 본체 Material 적용")

    body_mat = bpy.data.materials.new(name=f"Dice_Body_{color_name}")
    body_mat.use_nodes = True
    bsdf = body_mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = dice_color
    bsdf.inputs['Roughness'].default_value = 0.3
    bsdf.inputs['Metallic'].default_value = 0.1

    dice_body.data.materials.append(body_mat)
    print(f"  ✅ {color_name} 주사위 본체 Material 적용 완료")

    # ============================================================================
    # STEP 8: 최종 합치기
    # ============================================================================
    print("\n[STEP 8] 최종 합치기")

    if len(pip_fills) > 0:
        bpy.ops.object.select_all(action='DESELECT')
        dice_body.select_set(True)
        pips_combined.select_set(True)
        bpy.context.view_layer.objects.active = dice_body
        bpy.ops.object.join()

    dice_body.name = f"D6_Dice_{color_name}"

    # 폴리곤 수 확인
    print(f"  폴리곤 수: {len(dice_body.data.polygons)}")
    print("  ✅ 최종 합치기 완료")

print("\n" + "=" * 70)
print(f"✅ {len(colors_to_create)}개 주사위 생성 완료!")
print("=" * 70)

# ============================================================================
# STEP 9: 조명 및 카메라
# ============================================================================
print("\n[STEP 9] 조명 및 카메라 설정")

bpy.ops.object.light_add(type='SUN', location=(5, -5, 8))
light = bpy.context.active_object
light.data.energy = 3.0
light.rotation_euler = (math.radians(45), 0, math.radians(45))

bpy.ops.object.light_add(type='SUN', location=(-3, 3, 6))
fill_light = bpy.context.active_object
fill_light.data.energy = 1.0
fill_light.rotation_euler = (math.radians(60), 0, math.radians(-135))

bpy.ops.object.camera_add(location=(5, -5, 4))
camera = bpy.context.active_object
camera.rotation_euler = (math.radians(65), 0, math.radians(45))
bpy.context.scene.camera = camera

for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'MATERIAL'

print("  ✅ 씬 설정 완료")

# ============================================================================
# Export
# ============================================================================
project_path = "/Users/sangbro/colorcombodice2/"
export_dir = os.path.join(project_path, "assets/models")
os.makedirs(export_dir, exist_ok=True)

dice_objects = [
    "D6_Dice_Black",
    "D6_Dice_Blue",
    "D6_Dice_Green",
    "D6_Dice_Red",
    "D6_Dice_White"
]

for dice_name in dice_objects:
    color_suffix = dice_name.replace("D6_Dice_", "").lower()
    dice_export_path = os.path.join(export_dir, f"dice_{color_suffix}.gltf")

    bpy.ops.object.select_all(action='DESELECT')
    dice_object = bpy.data.objects.get(dice_name)

    if dice_object:
        dice_object.select_set(True)
        bpy.context.view_layer.objects.active = dice_object

        # 최적화된 Export 설정
        bpy.ops.export_scene.gltf(
            filepath=dice_export_path,
            use_selection=True,
            export_format='GLTF_SEPARATE',
            export_apply=True,
            export_materials='EXPORT',
            export_normals=True,
            export_tangents=False,
            export_texcoords=True,
            export_attributes=True,
        )

        print(f"✅ {dice_name} exported to: {dice_export_path}")
        print(f"   폴리곤 수: {len(dice_object.data.polygons)}")
    else:
        print(f"❌ {dice_name} not found!")

print("\n" + "=" * 70)
print("✅ 최적화된 주사위 Export 완료!")
print("=" * 70)
