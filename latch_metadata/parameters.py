from dataclasses import dataclass
import typing
import typing_extensions

from flytekit.core.annotation import FlyteAnnotation

from latch.types.metadata import SnakemakeParameter, SnakemakeFileParameter, SnakemakeFileMetadata
from latch.types.file import LatchFile
from latch.types.directory import LatchDir



# Import these into your `__init__.py` file:
#
# from .parameters import generated_parameters, file_metadata

generated_parameters = {
    'samplesheet': SnakemakeParameter(
        display_name='Samplesheet (TSV)',
        type=LatchFile,
    ),
    'genomes_dir': SnakemakeParameter(
        display_name='Reference Genomes Directory',
        type=LatchDir,
    ),
}

file_metadata = {
    'samplesheet': SnakemakeFileMetadata(
        path='samplesheet.tsv',
        config=True,
        download=True,
    ),
    'genomes_dir': SnakemakeFileMetadata(
        path='genomes',
        config=True,
    ),
}

