from dataclasses import dataclass
from pathlib import Path

from snakemake.io import Wildcards
from fgpyo.util.metric import Metric
from latch.ldata.path import LPath


@dataclass(kw_only=True, frozen=True)
class Sample(Metric["Sample"]):
    """A single row in the samplesheet."""
    sample_id: str
    reference_id: str


def workflow_is_executing_on_latch() -> bool:
    """True if the workflow is executing on Latch."""
    # https://github.com/latchbio/latch/blob/51f74f8f60977306bfd884a81b1b5a9203afc411/latch/utils.py#L168
    return os.environ.get("FLYTE_INTERNAL_EXECUTION_ID") is not None


def latchfile_exists(latch_uri: str) -> bool:
    """True if the specified Latch URI exists."""
    assert_path_is_latch_uri(latch_uri)

    try:
        LPath(path=latch_uri).fetch_metadata()
    except LatchPathError:
        return False

    return True



def assert_path_is_latch_uri(path: str) -> None:
    """Raise a ValueError if the path is not a Latch URI"""
    if not path.startswith("latch://"):
        raise ValueError(f"Path is not a Latch URI: {path}")


def get_samples() -> dict[str, Sample]:
    return {s.sample_id: s for s in Sample.read(Path(config["samplesheet"]))}


def reference_fasta(wildcards: Wildcards) -> str:
    """Return the path to a sample's reference."""
    sample: Sample = get_samples()[wildcards.sample]
    reference_id: str = sample.reference_id

    # Look for a pre-built reference in the configured reference genome directory.
    prebuilt_path = prebuilt_reference_fasta(reference_id)

    # Prepare a path to a reference file built by this workflow.
    new_path = os.path.join("results/build_reference", reference_id, f"{reference_id}.fna")

    if workflow_is_executing_on_latch():
        assert_path_is_latch_uri(config["genomes_dir"])
        fasta_path = prebuilt_path if latchfile_exists(prebuilt_path) else new_path
    else:
        fasta_path = prebuilt_path if os.path.exists(prebuilt_path) else new_path

    return fasta_path


def prebuilt_reference_fasta(reference_id: str) -> str:
    """Construct a path to a reference FASTA in the configured reference genome directory."""
    # NB: Use `os.path` rather than `pathlib` so we don't bork a Latch URI
    prebuilt_path = os.path.join(config['genomes_dir'], reference_id, f"{reference_id}.fna")

    return prebuilt_path


rule all:
    input:
        expand("results/print_reference_path/{sample}.txt", sample=get_samples()),
        "results/collect_reference_paths/collected_reference_paths.txt"


rule build_reference:
    """Build a reference and copy it to the configured reference location."""
    output:
        fasta="results/build_reference/{reference_id}/{reference_id}.fna"
    params:
        destination_path=lambda wildcards: prebuilt_reference_fasta(wildcards.reference_id),
        cp_cmd=lambda wildcards: "latch cp" if workflow_is_executing_on_latch() else "cp"
    log:
        "logs/build_reference/{reference_id}.log"
    shell:
        """
        (
        date > {output.fasta};
        {params.cp_cmd} {output.fasta} {params.destination_path};
        ) &> {log}
        """


rule print_reference_path:
    """Print the inferred path to the reference FASTA for each sample."""
    input:
        reference_fasta=reference_fasta
    output:
        txt="results/print_reference_path/{sample}.txt"
    log:
        "logs/print_reference_path/{sample}.log"
    threads: 1
    shell:
        """
        (
        echo "{wildcards.sample}\t{input.reference_fasta}" > {output.txt}
        ) &> {log}
        """


rule collect_reference_paths:
    """Concatenate the inferred paths for all samples."""
    input:
        printed_paths=expand("results/print_reference_path/{sample}.txt", sample=get_samples())
    output:
        txt="results/collect_reference_paths/collected_reference_paths.txt"
    log:
        "logs/collect_reference_paths.log"
    threads: 1
    shell:
        """
        (
        cat <(echo -e "sample_id\treference_path") {input.printed_paths} > {output.txt}
        ) &> {log}
        """


