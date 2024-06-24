from dataclasses import dataclass
from pathlib import Path

from snakemake.io import Wildcards
from fgpyo.util.metric import Metric
from latch.ldata.path import LPath


####################################################################################################
# Samplesheet utilities
####################################################################################################
@dataclass(kw_only=True, frozen=True)
class Sample(Metric["Sample"]):
    """A single row in the samplesheet."""
    sample_id: str
    reference_id: str


def get_samples() -> dict[str, Sample]:
    return {s.sample_id: s for s in Sample.read(Path(config["samplesheet"]))}


####################################################################################################
# Latch utilities
####################################################################################################
def workflow_is_executing_on_latch() -> bool:
    """True if the workflow is executing on Latch."""
    # https://github.com/latchbio/latch/blob/51f74f8f60977306bfd884a81b1b5a9203afc411/latch/utils.py#L168
    return os.environ.get("FLYTE_INTERNAL_EXECUTION_ID") is not None


def assert_path_is_latch_uri(path: str) -> None:
    """Raise a ValueError if the path is not a Latch URI."""
    if not path.startswith("latch://"):
        raise ValueError(f"Path is not a Latch URI: {path}")


def latchfile_exists(latch_uri: str) -> bool:
    """True if the specified Latch URI exists."""
    assert_path_is_latch_uri(latch_uri)

    try:
        LPath(path=latch_uri).fetch_metadata()
    except LatchPathError:
        return False
    else:
        return True


####################################################################################################
# Input functions
####################################################################################################
def reference_fasta(wildcards: Wildcards) -> str:
    """
    Return the path to a sample's reference FASTA.
    
    This input function permits conditional execution of `build_reference`. When a reference does
    not exist at the expected location in the configured reference genomes directory
    (`config['genomes_dir']`), this function returns a local path to the FASTA produced by
    `build_reference`. Otherwise, when a reference already exists, its path is returned. 

    This function supports both local and Latch execution. 
    """
    sample: Sample = get_samples()[wildcards.sample]
    reference_id: str = sample.reference_id

    # Look for a pre-built reference in the configured reference genome directory.
    prebuilt_path = prebuilt_reference_fasta(reference_id)

    # Prepare a path to a reference file built by this workflow.
    new_path = os.path.join("results/build_reference", reference_id, f"{reference_id}.fna")

    if workflow_is_executing_on_latch():
        fasta_path = prebuilt_path if latchfile_exists(prebuilt_path) else new_path
    else:
        fasta_path = prebuilt_path if os.path.exists(prebuilt_path) else new_path

    return fasta_path


def prebuilt_reference_fasta(reference_id: str) -> str:
    """
    Construct a path to a reference FASTA in the configured reference genome directory.

    NB: This function accepts a `str` instead of a `Wildcards` object so it can be used both as an
    input function (for `build_reference`'s `params.destination_path`) and as a helper for the
    `reference_fasta` input function. 
    """
    if workflow_is_executing_on_latch():
        # Latch's JIT replaces each Latch URI in the config with a path to the local file.
        # The `_latchfiles` field contains a mapping of each config key to the original Latch URI.
        genomes_dir = config["_latchfiles"]["genomes_dir"]
    else:
        genomes_dir = config["genomes_dir"]

    # NB: Use `os.path` rather than `pathlib` so we don't bork a Latch URI
    prebuilt_path = os.path.join(genomes_dir, reference_id, f"{reference_id}.fna")

    return prebuilt_path


####################################################################################################
# Rules
####################################################################################################
rule all:
    input:
        expand("results/print_reference_path/{sample}.txt", sample=get_samples()),
        "results/collect_reference_paths/collected_reference_paths.txt"


rule build_reference:
    """
    Build a reference and copy it to the configured reference location.

    This rule is executed conditionally. If a built reference already exists in the configured
    reference genomes directory (`config['genomes_dir']`), the rule is **not** executed.
    Otherwise, a new reference is built.

    Output:
        fasta: A newly constructed "reference".
    
    Params:
        destination_path: The expected path to the reference in the configured reference genomes
            directory. The built reference will be copied to this location after construction.
        cp_cmd: The command to use to copy the reference to the reference genomes directory. If the
            workflow is executing on Latch, the reference genomes directory is assumed to be on
            Latch, and `latch cp` is used. Otherwise, `cp` is used to copy the file to a local
            directory.
    """
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
        echo ">my_ref" > {output.fasta};
        echo "GATTACA" >> {output.fasta};
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


