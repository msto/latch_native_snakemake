from dataclasses import dataclass
from pathlib import Path

from snakemake.io import Wildcards
from fgpyo.util.metric import Metric


@dataclass(kw_only=True, frozen=True)
class Sample(Metric["Sample"]):
    """Represent a single line in the metadata tsv."""

    sample_id: str
    reference_id: str


def get_samples() -> dict[str, Sample]:
    return {s.sample_id: s for s in Sample.read(Path(config["metadata_tsv"]))}


def reference_fasta(wildcards: Wildcards) -> Path:
    """Return the path to a sample's reference."""
    sample: Sample = get_samples()[wildcards.sample]
    reference_id: str = sample.reference_id

    return Path(config["genomes_dir"]) / reference_id / f"{reference_id}.fna"


rule all:
    input:
        expand("results/print_reference_path/{sample}.txt", sample=get_samples()),
        "results/collect_reference_paths/collected_reference_paths.txt"


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


