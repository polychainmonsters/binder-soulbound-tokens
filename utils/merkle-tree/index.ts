import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

type Value = {
  address: string;
  points: number;
  rank: number;
  week: number;
};

export const getTree = (values: Value[]) => {
  const tree = StandardMerkleTree.of(
    values.map(({ address, points, rank, week }) => [
      address,
      points,
      rank,
      week,
    ]),
    ["address", "uint224", "uint16", "uint16"]
  );

  return tree;
};

export const getProof = ({
  tree,
  receiver,
}: {
  tree: StandardMerkleTree<(string | number)[]>;
  receiver: string;
}) => {
  for (const [i, v] of tree.entries()) {
    if (v[0] === receiver) {
      return { value: v, proof: tree.getProof(i) };
    }
  }
};
