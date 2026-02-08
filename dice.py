import bpy
import math
import os
import random

# ============================================================================
# 초기화
# ============================================================================
# 모드 변경 (에러 방지)
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

# 기존 오브젝트 및 데이터 삭제
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

for mat in bpy.data.materials:
    bpy.data.materials.remove(mat)
for tex in bpy.data.textures:
    bpy.data.textures.remove(tex)
for img in bpy.data.images:
    bpy.data.images.remove(img)

# ============================================================================
# 파라미터 설정
# ============================================================================
dice_size = 2.0
pip_size = 0.35
pip_depth = 0.25
bevel_amount = 0.08
pip_spacing = 0.5

# 표면 디테일 (0으로 설정하여 비닐 현상 원천 차단)
pip_subdivisions = 0      
pip_displacement = 0.0   
dice_subdivisions = 0     
dice_displacement = 0.0  
edge_subdivisions = 1     
edge_displacement = 0.005 
edge_bevel_segments = 1   

# [균열 설정] - 노멀 맵 파라미터 (안전한 방식)
add_cracks = True         
crack_scale = 3.5         # 패턴 크기 (클수록 자잘함)
crack_depth = 2.0         # 균열의 시각적 깊이감
crack_roughness = 0.9     # 균열 부위의 거칠기

# 색상 설정
dice_colors = {
    "Red": (1.0, 0.0, 0.0, 1.0),
    "Blue": (0.0, 0.0, 1.0, 1.0),
    "Green": (0.0, 1.0, 0.0, 1.0),
    "White": (1.0, 1.0, 1.0, 1.0),
    "Black": (0.0, 0.0, 0.0, 1.0),
}

pip_colors = {
    "Red": (1.0, 1.0, 1.0, 1.0),
    "Blue": (1.0, 1.0, 1.0, 1.0),
    "Green": (0.0, 0.0, 0.0, 1.0),
    "White": (0.0, 0.0, 0.0, 1.0),
    "Black": (1.0, 1.0, 1.0, 1.0),
}

create_dice = {
    "Red": True,
    "Blue": True,
    "Green": True,
    "White": True,
    "Black": True,
}

print("=" * 70)
print("주사위 생성 시작: 형태 보존 + 노멀 맵 균열 (에러 수정판)")
print("=" * 70)

colors_to_create = [c for c, create in create_dice.items() if create]
print(f"생성할 색상: {colors_to_create}")

project_path = "/Users/sangbro/colorcombodice2/" # 경로 확인 필요
export_dir = os.path.join(project_path, "assets/models_cracked_normal")
os.makedirs(export_dir, exist_ok=True)

# ============================================================================
# 메인 루프
# ============================================================================
for dice_index, color_name in enumerate(colors_to_create):
    # 이전 객체 정리 (반복 시)
    if dice_index > 0:
        for obj in bpy.data.objects:
            if obj.type == 'MESH': bpy.data.objects.remove(obj, do_unlink=True)
    
    dice_color = dice_colors[color_name]
    print(f"\n[{color_name} 주사위 생성 중...]")
    
    # ------------------------------------------------------------------------
    # 1. 본체 및 눈 생성 (기존 로직 유지)
    # ------------------------------------------------------------------------
    bpy.ops.mesh.primitive_cube_add(size=dice_size)
    dice_body = bpy.context.active_object
    dice_body.name = f"Dice_Body_{color_name}"

    # Bevel (모서리)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.bevel(offset=bevel_amount, segments=edge_bevel_segments, profile=0.5)
    bpy.ops.object.mode_set(mode='OBJECT')

    # 눈 패턴
    pip_patterns = {
        1: [(0, 0)],
        2: [(-pip_spacing, pip_spacing), (pip_spacing, -pip_spacing)],
        3: [(-pip_spacing, pip_spacing), (0, 0), (pip_spacing, -pip_spacing)],
        4: [(-pip_spacing, pip_spacing), (pip_spacing, pip_spacing), (-pip_spacing, -pip_spacing), (pip_spacing, -pip_spacing)],
        5: [(-pip_spacing, pip_spacing), (pip_spacing, pip_spacing), (0, 0), (-pip_spacing, -pip_spacing), (pip_spacing, -pip_spacing)],
        6: [(-pip_spacing, pip_spacing), (pip_spacing, pip_spacing), (-pip_spacing, 0), (pip_spacing, 0), (-pip_spacing, -pip_spacing), (pip_spacing, -pip_spacing)],
    }
    faces = [
        (1, (0, 0, 1)), (6, (0, 0, -1)), (2, (1, 0, 0)),
        (5, (-1, 0, 0)), (3, (0, 1, 0)), (4, (0, -1, 0)),
    ]

    # 눈 생성
    all_pips = []
    for face_val, norm in faces:
        for px, py in pip_patterns[face_val]:
            bpy.ops.mesh.primitive_cube_add(size=pip_size)
            pip = bpy.context.active_object
            half = dice_size / 2
            if norm == (0, 0, 1): pip.location = (px, py, half + pip_depth/2)
            elif norm == (0, 0, -1): pip.location = (px, py, -half - pip_depth/2)
            elif norm == (1, 0, 0): pip.location = (half + pip_depth/2, px, py)
            elif norm == (-1, 0, 0): pip.location = (-half - pip_depth/2, px, py)
            elif norm == (0, 1, 0): pip.location = (px, half + pip_depth/2, py)
            elif norm == (0, -1, 0): pip.location = (px, -half - pip_depth/2, py)
            all_pips.append(pip)

    # Boolean (눈 파기)
    bpy.ops.object.select_all(action='DESELECT')
    for p in all_pips: p.select_set(True)
    bpy.context.view_layer.objects.active = all_pips[0]
    bpy.ops.object.join()
    combined_pips = bpy.context.active_object
    
    bpy.context.view_layer.objects.active = dice_body
    mod = dice_body.modifiers.new("SubPips", 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = combined_pips
    bpy.ops.object.modifier_apply(modifier="SubPips")
    bpy.data.objects.remove(combined_pips, do_unlink=True)

    # 눈 채우기
    pip_fills = []
    for face_val, norm in faces:
        for px, py in pip_patterns[face_val]:
            bpy.ops.mesh.primitive_cube_add(size=pip_size * 0.9)
            pf = bpy.context.active_object
            half = dice_size / 2
            ins = pip_depth * 0.7
            if norm == (0, 0, 1): pf.location = (px, py, half - ins)
            elif norm == (0, 0, -1): pf.location = (px, py, -half + ins)
            elif norm == (1, 0, 0): pf.location = (half - ins, px, py)
            elif norm == (-1, 0, 0): pf.location = (-half + ins, px, py)
            elif norm == (0, 1, 0): pf.location = (px, half - ins, py)
            elif norm == (0, -1, 0): pf.location = (px, -half + ins, py)
            pip_fills.append(pf)

    # 재질 적용 및 합치기 (이름 지정 방식 사용)
    # 1. 눈 재질
    if pip_fills:
        bpy.ops.object.select_all(action='DESELECT')
        for pf in pip_fills: pf.select_set(True)
        bpy.context.view_layer.objects.active = pip_fills[0]
        bpy.ops.object.join()
        pips_combined = bpy.context.active_object
        
        pmat_name = f"PipMat_{color_name}"
        pmat = bpy.data.materials.new(pmat_name)
        pmat.use_nodes = True
        pmat.node_tree.nodes.get("Principled BSDF").inputs['Base Color'].default_value = pip_colors[color_name]
        pmat.node_tree.nodes.get("Principled BSDF").inputs['Roughness'].default_value = 0.4
        pips_combined.data.materials.append(pmat)
        
        bpy.ops.object.select_all(action='DESELECT')
        dice_body.select_set(True)
        pips_combined.select_set(True)
        bpy.context.view_layer.objects.active = dice_body
        bpy.ops.object.join()

    # 2. 본체 재질 생성 (이름을 기억해둠)
    bmat_name = f"BodyMat_{color_name}"
    bmat = bpy.data.materials.new(bmat_name)
    bmat.use_nodes = True
    bsdf = bmat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs['Base Color'].default_value = dice_color
    bsdf.inputs['Roughness'].default_value = 0.3
    
    # 재질 추가 (기존 재질 슬롯 뒤에 추가됨)
    dice_body.data.materials.append(bmat)
    
    dice_body.name = f"D6_{color_name}_Final"
    
    # 원점 정리
    bpy.ops.object.select_all(action='DESELECT')
    dice_body.select_set(True)
    bpy.context.view_layer.objects.active = dice_body
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    dice_body.location = (0, 0, 0)


    # ============================================================================
    # [STEP 8.5] 균열: 노멀 맵 적용 (에러 수정됨)
    # ============================================================================
    if add_cracks:
        print("  ✅ [안전 모드] 노멀 맵 균열 적용 중...")
        
        # [수정된 부분] 재질을 이름으로 정확히 찾습니다.
        # 합치는 과정에서 재질 순서가 바뀌거나 None이 될 수 있으므로 이름으로 찾는 것이 가장 안전합니다.
        target_mat = bpy.data.materials.get(bmat_name)
        
        if target_mat:
            nodes = target_mat.node_tree.nodes
            links = target_mat.node_tree.links
            bsdf = nodes.get("Principled BSDF")
            
            # 노드: Voronoi (균열 패턴)
            voronoi = nodes.new(type="ShaderNodeTexVoronoi")
            voronoi.feature = 'DISTANCE_TO_EDGE' 
            voronoi.inputs['Scale'].default_value = crack_scale
            voronoi.location = (-600, 300)
            
            # 노드: Color Ramp (날카로운 선 만들기)
            ramp = nodes.new(type="ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].position = 0.02
            ramp.color_ramp.elements[0].color = (1, 1, 1, 1) # 흰색
            ramp.color_ramp.elements[1].position = 0.05
            ramp.color_ramp.elements[1].color = (0, 0, 0, 1) # 검은색
            ramp.location = (-300, 300)
            
            # 노드: Bump (높이 -> 노멀 변환)
            bump = nodes.new(type="ShaderNodeBump")
            bump.inputs['Strength'].default_value = crack_depth
            bump.location = (-100, 100)
            
            # 연결
            links.new(voronoi.outputs['Distance'], ramp.inputs['Fac'])
            links.new(ramp.outputs['Color'], bump.inputs['Height'])
            links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
            
            # 거칠기 조절
            bsdf.inputs['Roughness'].default_value = crack_roughness

            print(f"  ✅ '{bmat_name}'에 균열 노멀 맵 적용 완료")
        else:
            print(f"  ⚠️ 경고: '{bmat_name}' 재질을 찾을 수 없습니다.")

    # ------------------------------------------------------------------------
    # Export
    # ------------------------------------------------------------------------
    out_path = os.path.join(export_dir, f"0_dice_{color_name.lower()}_cracked.gltf")
    bpy.ops.object.select_all(action='DESELECT')
    dice_body.select_set(True)
    bpy.context.view_layer.objects.active = dice_body
    
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        use_selection=True,
        export_format='GLTF_SEPARATE',
        export_apply=True,
        export_materials='EXPORT' 
    )
    print(f"  ✅ 저장 완료: {out_path}")

# 미리보기용 조명
bpy.ops.object.light_add(type='SUN', location=(5, -5, 8))
bpy.context.active_object.data.energy = 3.0
bpy.ops.object.camera_add(location=(5, -5, 4))
bpy.context.active_object.rotation_euler = (math.radians(65), 0, math.radians(45))
bpy.context.scene.camera = bpy.context.active_object

# 뷰포트 쉐이딩 설정
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'MATERIAL'

print("\n완료! 에러 없이 정상적으로 생성되었습니다.")