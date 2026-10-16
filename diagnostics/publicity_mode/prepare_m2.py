"""Prepare fresh, local M2 reference benches and enabled synthesis wrappers."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=False)
baseline = "8a90155"


def complete_pins(text, module, source=None):
    """Explicit unused output pins in generated legacy test copies, no suppression."""
    if source is None:
        source = (ROOT / f"user_source/hdl_source/SD/{module}.v").read_text(encoding="utf-8")
    port_start = re.search(r"\)\s*\(", source).end()
    ports = re.sub(r"//[^\n]*", "", source[port_start:source.index(");")])
    names = [re.sub(r"\[[^]]*\]", "", c).split()[-1] for c in ports.split(",")]
    def fill(match):
        instance = match.group()
        missing = [n for n in names if not re.search(rf"\.{n}\s*\(", instance)]
        values = {"map_start": "1'b0", "resource_publicity": "1'b0", "pixel_ready": "1'b1"}
        extra = ",".join(f".{n}({values.get(n, '')})" for n in missing)
        return instance[:-2] + (",\n" + extra if extra else "") + ");"
    return re.sub(rf"(?s)\b{module}\s*#\(.*?\)\s+\w+\s*\(.*?\);", fill, text)


for module, bench, top in (
    ("fat32_volume_scanner", "diagnostics/mountain_scene/tb_m5_scan.sv", "tb_m5_scan"),
    ("fat32_bmp_reader", "diagnostics/fat32/tb_fat32_reader.sv", "tb_fat32_reader"),
):
    path = f"user_source/hdl_source/SD/{module}.v"
    original = subprocess.check_output(["git", "show", f"{baseline}:{path}"], cwd=ROOT).decode("utf-8")
    reference = original.replace(f"module {module}", f"module {module}_reference", 1)
    if module == "fat32_bmp_reader":
        reference = complete_pins(reference, "fat32_volume_scanner")
    (out / f"{module}_reference.v").write_text(reference, encoding="utf-8")
    tb = (ROOT / bench).read_text(encoding="utf-8")
    instance = re.search(rf"(?s){module} #.*?;", tb).group()
    # Existing port list contains only legacy names. Reuse the identical inputs,
    # disconnect every reference output, compare all legacy output pins each cycle.
    header = original[:original.index("localparam")]
    outputs = []
    direction = None
    for chunk in header[header.index(")(") + 2:header.rfind(");")].split(","):
        words = re.sub(r"\[[^]]*\]", "", chunk).split()
        if "input" in words:
            direction = "input"
        if "output" in words:
            direction = "output"
        name = words[-1]
        if direction == "output":
            outputs.append(name)
    ref_instance = instance.replace(module, module + "_reference", 1).replace(" dut(", " reference_dut(")
    for port in outputs:
        ref_instance = re.sub(rf"\.{port}\([^)]*\)", f".{port}()", ref_instance)
    ref_instance = complete_pins(ref_instance, module + "_reference", original)
    lhs = ",".join(f"dut.{p}" for p in outputs)
    rhs = ",".join(f"reference_dut.{p}" for p in outputs)
    extra = f'\n{ref_instance}\nalways @(posedge clk) begin #1; if(!rst && {{{lhs}}} !== {{{rhs}}}) $fatal(1,"M2 default-off {module} cycle mismatch");end\n'
    tb = complete_pins(tb, module)
    tb = tb.replace("module " + top, "module " + top + "_equivalence", 1).replace("endmodule", extra + "endmodule")
    (out / f"{top}_equivalence.sv").write_text(tb, encoding="utf-8")

    # A real opt-in wrapper retains the current source unmodified, exposes all
    # module pins, and selects the enabled parameters for standalone synthesis.
    current = (ROOT / path).read_text(encoding="utf-8")
    port_text = current[current.index(")(") + 2:current.index(");")]
    port_text = re.sub(r"//[^\n]*", "", port_text)
    ports = []
    for chunk in port_text.split(","):
        ports.append(re.sub(r"\[[^]]*\]", "", chunk).split()[-1])
    pins = ",\n".join(f".{p}({p})" for p in ports)
    params = ".SCAN_PUBLICITY(1),.SCAN_AUDIO(1),.SCAN_TEXT(1)"
    if module == "fat32_bmp_reader":
        params += ",.LOAD_BY_INDEX(1),.SCALE_ENABLE(1)"
    wrapper = f"module {module}_enabled({port_text.replace('output reg', 'output wire')});\n{module} #({params}) dut({pins});\nendmodule\n"
    (out / f"{module}_enabled.v").write_text(wrapper, encoding="utf-8")
print(f"Prepared M2 references from {baseline} and enabled wrappers in {out}")
for bench in ("diagnostics/pcm_audio/tb_audio_scan.sv", "diagnostics/mountain_scene/tb_snd_scan.sv", "diagnostics/fat32/tb_fat32_core.sv"):
    tb = (ROOT / bench).read_text(encoding="utf-8")
    if bench.endswith("tb_fat32_core.sv"):
        tb = tb.replace("diagnostics/output/fat32_core/fixtures", (out / "fixtures").as_posix())
        tb = complete_pins(tb, "bmp24_decoder")
    (out / Path(bench).name).write_text(complete_pins(tb, "fat32_volume_scanner"), encoding="utf-8")
